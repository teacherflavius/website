let currentSession = null;

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("frequencia/index.html");
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function waitForAuthResources() {
  for (let i = 0; i < 12; i++) {
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

function formatBrazilianDate(value) {
  if (!value) return "Não informado";
  const parts = String(value).split("-");
  if (parts.length === 3) return parts[2] + "/" + parts[1] + "/" + parts[0].slice(2);
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit", year: "2-digit" });
}

async function loadMyLessonRecords() {
  const client = Auth.getClient();
  const response = await client.rpc("get_my_lesson_records");
  if (response.error) throw response.error;
  return response.data || [];
}

function renderTable(records) {
  return '<div class="frequency-table-wrap">' +
    '<table class="frequency-table">' +
      '<thead><tr><th>Data da aula</th><th>Lição registrada</th><th>Turma</th></tr></thead>' +
      '<tbody>' + records.map(function (record) {
        return '<tr>' +
          '<td>' + escapeHtml(formatBrazilianDate(record.class_date)) + '</td>' +
          '<td><span class="lesson-pill">' + escapeHtml(record.lesson_code || "") + '</span></td>' +
          '<td>' + escapeHtml(record.class_name || "Turma") + '</td>' +
        '</tr>';
      }).join("") + '</tbody>' +
    '</table>' +
  '</div>';
}

async function renderFrequency() {
  const content = document.getElementById("frequencyContent");
  const totalClasses = document.getElementById("totalClasses");
  const lastLesson = document.getElementById("lastLesson");

  try {
    const records = await loadMyLessonRecords();
    if (totalClasses) totalClasses.textContent = String(records.length);
    if (lastLesson) lastLesson.textContent = records.length ? records[0].lesson_code : "—";

    if (!records.length) {
      content.className = "empty-panel";
      content.textContent = "Nenhuma aula foi registrada pelo professor ainda.";
      return;
    }

    content.className = "";
    content.innerHTML = renderTable(records);
  } catch (error) {
    if (totalClasses) totalClasses.textContent = "0";
    if (lastLesson) lastLesson.textContent = "—";
    content.className = "empty-panel";
    content.textContent = "Não foi possível carregar sua frequência. Execute supabase_frequencia_aluno.sql no Supabase.";
  }
}

async function guardPage() {
  const status = document.getElementById("loginStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentSession = await Auth.getSession();
  if (!currentSession || !currentSession.user) {
    redirectToLogin();
    return;
  }

  status.textContent = "Aluno conectado: " + currentSession.user.email + ".";
  document.body.classList.remove("auth-checking");
  await renderFrequency();
}

guardPage();
