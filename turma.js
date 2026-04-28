let currentProfessorSession = null;
let currentClassNumber = null;
let allStudents = [];
let classStudentIds = new Set();

function getClassNumber() {
  const params = new URLSearchParams(window.location.search);
  const value = Number(params.get("id"));
  if (!Number.isInteger(value) || value < 1 || value > 45) return null;
  return value;
}

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("turma.html?id=" + currentClassNumber);
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatDateInput(value) {
  const digits = String(value || "").replace(/\D/g, "").slice(0, 6);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) return digits.slice(0, 2) + "/" + digits.slice(2);
  return digits.slice(0, 2) + "/" + digits.slice(2, 4) + "/" + digits.slice(4);
}

function parseBrazilianShortDate(value) {
  const match = String(value || "").match(/^(\d{2})\/(\d{2})\/(\d{2})$/);
  if (!match) throw new Error("Informe a data no formato DD/MM/AA.");

  const day = Number(match[1]);
  const month = Number(match[2]);
  const year = 2000 + Number(match[3]);
  const date = new Date(year, month - 1, day);

  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    throw new Error("Data inválida. Use o formato DD/MM/AA.");
  }

  return String(year) + "-" + String(month).padStart(2, "0") + "-" + String(day).padStart(2, "0");
}

function isEnrolled(student) {
  return student.enrolled === true || student.enrolled === "true" || !!student.enrollment_code;
}

function getClassStudents() {
  return allStudents.filter(function (student) {
    return classStudentIds.has(student.user_id || student.id);
  });
}

async function loadStudents() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_students");
  if (response.error) throw response.error;
  return (response.data || []).filter(isEnrolled);
}

async function loadClassStudents() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_class_students", { target_class_number: currentClassNumber });
  if (response.error) throw response.error;
  return response.data || [];
}

async function addStudentToClass(userId, button) {
  button.disabled = true;
  button.textContent = "ADICIONANDO...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("add_teacher_class_student", {
      target_class_number: currentClassNumber,
      target_user_id: userId
    });
    if (response.error) throw response.error;
    await refreshLists();
  } catch (error) {
    alert("Não foi possível adicionar o aluno: " + (error.message || "erro desconhecido") + ". Execute supabase_turmas.sql no Supabase.");
    button.disabled = false;
    button.textContent = "ADICIONAR À TURMA";
  }
}

async function removeStudentFromClass(userId, button) {
  const confirmed = window.confirm("Remover este aluno da turma " + currentClassNumber + "?");
  if (!confirmed) return;

  button.disabled = true;
  button.textContent = "REMOVENDO...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("remove_teacher_class_student", {
      target_class_number: currentClassNumber,
      target_user_id: userId
    });
    if (response.error) throw response.error;
    await refreshLists();
  } catch (error) {
    alert("Não foi possível remover o aluno: " + (error.message || "erro desconhecido") + ". Execute supabase_turmas.sql no Supabase.");
    button.disabled = false;
    button.textContent = "REMOVER DA TURMA";
  }
}

function renderStudentCard(student, action) {
  const userId = escapeHtml(student.user_id || student.id);
  const name = escapeHtml(student.name || student.email || "Aluno sem nome");
  const email = escapeHtml(student.email || "Não informado");
  const enrollmentCode = escapeHtml(student.enrollment_code || "Não informado");

  const button = action === "remove"
    ? '<button class="delete-button remove-class-student" data-user-id="' + userId + '">REMOVER DA TURMA</button>'
    : '<button class="delete-button add-class-student" data-user-id="' + userId + '" style="border-color:rgba(129,140,248,0.45); background:rgba(129,140,248,0.10); color:#c4b5fd;">ADICIONAR À TURMA</button>';

  return '<div class="student-card">' +
    '<strong>' + name + '</strong>' +
    '<p><b>E-mail:</b> ' + email + '</p>' +
    '<p><b>Número de matrícula:</b> ' + enrollmentCode + '</p>' +
    button +
  '</div>';
}

function renderAttendanceStudents() {
  const list = document.getElementById("attendanceStudentsList");
  if (!list) return;

  const classStudents = getClassStudents();
  if (!classStudents.length) {
    list.className = "empty";
    list.textContent = "Adicione alunos à turma antes de registrar uma aula.";
    return;
  }

  list.className = "";
  list.innerHTML = classStudents.map(function (student) {
    const userId = escapeHtml(student.user_id || student.id);
    const name = escapeHtml(student.name || student.email || "Aluno sem nome");
    const email = escapeHtml(student.email || "Não informado");
    return '<div class="class-attendance-row">' +
      '<label><input type="checkbox" class="attendance-student-check" data-user-id="' + userId + '" checked />' + name + '</label>' +
      '<p style="color:#94a3b8; font-size:13px; margin-bottom:8px;"><b>E-mail:</b> ' + email + '</p>' +
      '<select class="attendance-status" data-user-id="' + userId + '">' +
        '<option value="Compareceu">Compareceu</option>' +
        '<option value="Faltou">Faltou</option>' +
      '</select>' +
      '<textarea class="attendance-notes" data-user-id="' + userId + '" placeholder="Observação individual opcional para este aluno..."></textarea>' +
    '</div>';
  }).join("");
}

function attachClassButtons() {
  document.querySelectorAll(".add-class-student").forEach(function (button) {
    button.addEventListener("click", function () {
      addStudentToClass(button.dataset.userId, button);
    });
  });

  document.querySelectorAll(".remove-class-student").forEach(function (button) {
    button.addEventListener("click", function () {
      removeStudentFromClass(button.dataset.userId, button);
    });
  });
}

function renderLists() {
  const classList = document.getElementById("classStudentsList");
  const availableList = document.getElementById("availableStudentsList");

  const classStudents = getClassStudents();
  const availableStudents = allStudents.filter(function (student) {
    return !classStudentIds.has(student.user_id || student.id);
  });

  if (!classStudents.length) {
    classList.className = "empty";
    classList.textContent = "Nenhum aluno adicionado a esta turma ainda.";
  } else {
    classList.className = "";
    classList.innerHTML = classStudents.map(function (student) {
      return renderStudentCard(student, "remove");
    }).join("");
  }

  if (!availableStudents.length) {
    availableList.className = "empty";
    availableList.textContent = "Todos os alunos matriculados já estão nesta turma.";
  } else {
    availableList.className = "";
    availableList.innerHTML = availableStudents.map(function (student) {
      return renderStudentCard(student, "add");
    }).join("");
  }

  renderAttendanceStudents();
  attachClassButtons();
}

async function refreshLists() {
  const classRows = await loadClassStudents();
  classStudentIds = new Set(classRows.map(function (row) { return row.user_id; }));
  renderLists();
}

async function saveClassAttendance(event) {
  event.preventDefault();
  const message = document.getElementById("attendanceMessage");
  message.className = "empty";
  message.textContent = "Salvando frequência...";

  try {
    const classDate = parseBrazilianShortDate(document.getElementById("classDate").value);
    const generalNotes = document.getElementById("classNotes").value.trim();
    const selectedChecks = Array.from(document.querySelectorAll(".attendance-student-check:checked"));

    if (!selectedChecks.length) {
      throw new Error("Selecione pelo menos um aluno para registrar a aula.");
    }

    const attendanceRecords = selectedChecks.map(function (checkbox) {
      const userId = checkbox.dataset.userId;
      const statusInput = document.querySelector('.attendance-status[data-user-id="' + userId + '"]');
      const notesInput = document.querySelector('.attendance-notes[data-user-id="' + userId + '"]');
      return {
        user_id: userId,
        attendance_status: statusInput ? statusInput.value : "Compareceu",
        class_notes: notesInput && notesInput.value.trim() ? notesInput.value.trim() : generalNotes
      };
    });

    const client = Auth.getClient();
    const response = await client.rpc("save_teacher_class_attendance", {
      target_class_number: currentClassNumber,
      target_class_date: classDate,
      target_general_notes: generalNotes,
      attendance_records: attendanceRecords
    });

    if (response.error) throw response.error;

    document.getElementById("classAttendanceForm").reset();
    renderAttendanceStudents();
    message.className = "empty";
    message.textContent = "Frequência da aula salva.";
  } catch (error) {
    message.className = "error";
    message.textContent = error.message || "Não foi possível salvar a frequência.";
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  currentClassNumber = getClassNumber();

  if (!currentClassNumber) {
    document.getElementById("classTitle").textContent = "Turma inválida";
    status.textContent = "Informe uma turma entre 1 e 45.";
    document.body.classList.remove("auth-checking");
    return;
  }

  document.getElementById("classTitle").textContent = "Turma " + currentClassNumber;

  const resourcesReady = await waitForAuthResources();
  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentProfessorSession = await Auth.getSession();
  if (!currentProfessorSession || !currentProfessorSession.user) {
    redirectToLogin();
    return;
  }

  try {
    status.textContent = "Professor autenticado: " + currentProfessorSession.user.email + ".";
    allStudents = await loadStudents();
    await refreshLists();
    document.body.classList.remove("auth-checking");
  } catch (error) {
    status.textContent = "Não foi possível carregar a turma: " + (error.message || "erro desconhecido") + ". Execute supabase_turmas.sql no Supabase.";
    document.body.classList.remove("auth-checking");
  }
}

const classDateInput = document.getElementById("classDate");
if (classDateInput) {
  classDateInput.addEventListener("input", function () {
    this.value = formatDateInput(this.value);
  });
}

const classAttendanceForm = document.getElementById("classAttendanceForm");
if (classAttendanceForm) classAttendanceForm.addEventListener("submit", saveClassAttendance);

guardPage();
