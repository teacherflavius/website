let currentProfessorUser = null;

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

function formatDateTime(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  });
}

async function loadExerciseCompletions() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_daily_exercise_completion");
  if (response.error) throw response.error;
  return response.data || [];
}

function groupByStudent(records) {
  return records.reduce(function (groups, record) {
    const key = record.user_id || record.student_email || "sem-id";
    if (!groups[key]) {
      groups[key] = {
        studentName: record.student_name || "Aluno sem nome",
        studentEmail: record.student_email || "E-mail não informado",
        items: []
      };
    }
    groups[key].items.push(record);
    return groups;
  }, {});
}

function renderStudentGroup(group) {
  const items = group.items.map(function (record) {
    return '<div class="record" style="background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.08); border-radius:12px; padding:12px; margin-top:10px;">' +
      '<strong style="display:block; color:#f1f5f9; margin-bottom:5px;">' + escapeHtml(record.exercise_title || record.exercise_id) + '</strong>' +
      '<p><b>Marcado em:</b> ' + escapeHtml(formatDateTime(record.completed_at || record.updated_at)) + '</p>' +
      (record.exercise_url ? '<p><a href="' + escapeHtml(record.exercise_url) + '" target="_blank" rel="noopener noreferrer" style="color:#818cf8;">Abrir exercício</a></p>' : '') +
    '</div>';
  }).join("");

  return '<div class="student-card">' +
    '<strong>' + escapeHtml(group.studentName) + '</strong>' +
    '<p><b>E-mail:</b> ' + escapeHtml(group.studentEmail) + '</p>' +
    '<p><b>Total marcado como feito:</b> ' + group.items.length + '</p>' +
    items +
  '</div>';
}

async function renderExerciseCompletions() {
  const list = document.getElementById("exerciseCompletionList");
  try {
    const records = await loadExerciseCompletions();

    if (!records.length) {
      list.className = "empty";
      list.textContent = "Nenhum exercício foi marcado como feito pelos alunos matriculados ainda.";
      return;
    }

    const groups = groupByStudent(records);
    list.className = "";
    list.innerHTML = Object.keys(groups).map(function (key) {
      return renderStudentGroup(groups[key]);
    }).join("");
  } catch (error) {
    list.className = "error";
    list.textContent = "Não foi possível carregar os exercícios dos alunos: " + (error.message || "erro desconhecido") + ". Execute supabase_exercicios_diarios.sql no Supabase.";
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentProfessorUser = await Auth.requireTeacherAdmin("/exercicios-dos-alunos/");
  if (!currentProfessorUser) return;

  status.textContent = "Professor autenticado: " + currentProfessorUser.email + ".";
  document.body.classList.remove("auth-checking");
  await renderExerciseCompletions();
}

guardPage();
