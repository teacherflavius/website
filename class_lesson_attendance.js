(function () {
  function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }

  var specialLessonOptions = [
    "Feriado",
    "Teacher Cancelou",
    "Aluno cancelou",
    "Conversation",
    "Outras atividades",
    "Problemas técnicos"
  ];

  async function waitForAuthResources() {
    for (var i = 0; i < 20; i++) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured && Auth.isConfigured());
  }

  function getClassNumber() {
    var params = new URLSearchParams(window.location.search);
    var value = Number(params.get("id"));
    if (!Number.isInteger(value) || value < 1) return null;
    return value;
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatBrazilianDate(value) {
    if (!value) return "";
    var parts = String(value).split("-");
    if (parts.length === 3) return parts[2] + "/" + parts[1] + "/" + parts[0].slice(2);
    return value;
  }

  function todayIso() {
    var d = new Date();
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + day;
  }

  function lessonOptions(selected) {
    var html = '<option value="">Selecionar</option>';

    specialLessonOptions.forEach(function (option) {
      html += '<option value="' + escapeHtml(option) + '"' + (selected === option ? ' selected' : '') + '>' + escapeHtml(option) + '</option>';
    });

    html += '<option disabled>──────────</option>';

    for (var i = 1; i <= 74; i++) {
      var lesson = "L" + i;
      html += '<option value="' + lesson + '"' + (selected === lesson ? ' selected' : '') + '>' + lesson + '</option>';
    }
    return html;
  }

  async function loadClassStudents(classNumber) {
    var client = Auth.getClient();
    var response = await client.rpc("get_teacher_class_students", { target_class_number: classNumber });
    if (response.error) throw response.error;
    return response.data || [];
  }

  async function loadLessonRecords(classNumber) {
    var client = Auth.getClient();
    var response = await client.rpc("get_teacher_class_lesson_records", { target_class_number: classNumber });
    if (response.error) throw response.error;
    return response.data || [];
  }

  function groupRecordsByUser(records) {
    return records.reduce(function (map, record) {
      var userId = String(record.user_id || "");
      if (!map[userId]) map[userId] = [];
      map[userId].push(record);
      return map;
    }, {});
  }

  function renderRecordRows(student, records) {
    var rows = (records || []).map(function (record) {
      return '<tr>' +
        '<td>' + escapeHtml(formatBrazilianDate(record.class_date)) + '</td>' +
        '<td><span class="lesson-status-pill">' + escapeHtml(record.lesson_code || "") + '</span></td>' +
        '<td></td>' +
      '</tr>';
    }).join("");

    rows += '<tr>' +
      '<td><input class="lesson-date-input" type="date" value="' + todayIso() + '" data-user-id="' + escapeHtml(student.user_id) + '" /></td>' +
      '<td><select class="lesson-select" data-user-id="' + escapeHtml(student.user_id) + '">' + lessonOptions("") + '</select></td>' +
      '<td><button class="lesson-save-button" type="button" data-user-id="' + escapeHtml(student.user_id) + '">SALVAR</button></td>' +
    '</tr>';

    return rows;
  }

  function renderStudentTable(student, records) {
    var name = student.student_name || student.name || student.student_email || "Aluno sem nome";
    var enrollment = student.enrollment_code || "Não informado";

    return '<div class="lesson-attendance-card">' +
      '<table class="lesson-attendance-table">' +
        '<thead>' +
          '<tr><th>' + escapeHtml(name) + '</th><th colspan="2">Matrícula: ' + escapeHtml(enrollment) + '</th></tr>' +
        '</thead>' +
        '<tbody>' + renderRecordRows(student, records) + '</tbody>' +
      '</table>' +
    '</div>';
  }

  async function saveLessonRecord(button) {
    var userId = button.dataset.userId;
    var dateInput = document.querySelector('.lesson-date-input[data-user-id="' + userId + '"]');
    var lessonSelect = document.querySelector('.lesson-select[data-user-id="' + userId + '"]');
    var classNumber = getClassNumber();

    if (!dateInput || !lessonSelect || !classNumber) return;
    if (!dateInput.value) {
      alert("Escolha uma data.");
      return;
    }
    if (!lessonSelect.value) {
      alert("Escolha uma opção da lista.");
      return;
    }

    button.disabled = true;
    button.textContent = "SALVANDO...";

    try {
      var client = Auth.getClient();
      var response = await client.rpc("save_teacher_class_lesson_record", {
        target_class_number: classNumber,
        target_user_id: userId,
        target_class_date: dateInput.value,
        target_lesson_code: lessonSelect.value
      });
      if (response.error) throw response.error;
      await renderLessonAttendance();
    } catch (error) {
      alert("Não foi possível salvar o registro: " + (error.message || "erro desconhecido") + ". Execute supabase_licoes_opcoes_extras.sql no Supabase.");
      button.disabled = false;
      button.textContent = "SALVAR";
    }
  }

  function attachSaveButtons() {
    document.querySelectorAll(".lesson-save-button").forEach(function (button) {
      if (button.dataset.bound === "true") return;
      button.dataset.bound = "true";
      button.addEventListener("click", function () { saveLessonRecord(button); });
    });
  }

  async function renderLessonAttendance() {
    var target = document.getElementById("lessonAttendanceTables");
    var classNumber = getClassNumber();
    if (!target || !classNumber) return;

    try {
      var ready = await waitForAuthResources();
      if (!ready) throw new Error("Supabase não configurado.");
      var students = await loadClassStudents(classNumber);
      var records = await loadLessonRecords(classNumber);
      var grouped = groupRecordsByUser(records);

      if (!students.length) {
        target.className = "empty";
        target.textContent = "Adicione alunos à turma antes de registrar lições.";
        return;
      }

      target.className = "";
      target.innerHTML = students.map(function (student) {
        return renderStudentTable(student, grouped[String(student.user_id)] || []);
      }).join("");
      attachSaveButtons();
    } catch (error) {
      target.className = "error";
      target.textContent = "Não foi possível carregar a tabela de frequência. Execute supabase_licoes_turma.sql no Supabase.";
    }
  }

  window.renderLessonAttendance = renderLessonAttendance;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderLessonAttendance);
  } else {
    renderLessonAttendance();
  }
})();
