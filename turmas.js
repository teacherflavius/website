let currentProfessorSession = null;

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("turmas.html");
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

async function loadClasses() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_classes");
  if (response.error) throw response.error;
  return response.data || [];
}

function renderClassCard(classItem) {
  const classNumber = classItem.class_number;
  const className = classItem.class_name || ("Turma " + classNumber);
  const studentCount = Number(classItem.student_count || 0);

  return '<div class="class-card">' +
    '<div class="class-card-title"><span><span class="icon">🏫</span>' + escapeHtml(className) + '</span><span>Turma ' + escapeHtml(classNumber) + '</span></div>' +
    '<p style="color:#94a3b8; font-size:13px; line-height:1.5;">Alunos inscritos: ' + studentCount + '</p>' +
    '<div class="class-actions">' +
      '<a class="open-class-button" href="turma.html?id=' + encodeURIComponent(classNumber) + '">ABRIR TURMA</a>' +
      '<button class="remove-class-button" type="button" data-class-number="' + escapeHtml(classNumber) + '" data-class-name="' + escapeHtml(className) + '">EXCLUIR TURMA</button>' +
    '</div>' +
  '</div>';
}

async function renderClasses() {
  const grid = document.getElementById("classesGrid");
  try {
    const classes = await loadClasses();
    if (!classes.length) {
      grid.className = "empty";
      grid.textContent = "Nenhuma turma criada ainda.";
      return;
    }

    grid.className = "menu-grid";
    grid.innerHTML = classes.map(renderClassCard).join("");
    attachDeleteButtons();
  } catch (error) {
    grid.className = "error";
    grid.textContent = "Não foi possível carregar as turmas. Reexecute supabase_turmas.sql no Supabase.";
  }
}

async function createClass(event) {
  event.preventDefault();
  const message = document.getElementById("classMessage");
  const input = document.getElementById("className");
  const className = input.value.trim();

  message.className = "empty";
  message.textContent = "Criando turma...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("create_teacher_class", { target_class_name: className || null });
    if (response.error) throw response.error;
    input.value = "";
    message.className = "empty";
    message.textContent = "Turma criada.";
    await renderClasses();
  } catch (error) {
    message.className = "error";
    message.textContent = "Não foi possível criar a turma: " + (error.message || "erro desconhecido") + ". Reexecute supabase_turmas.sql no Supabase.";
  }
}

async function deleteClass(classNumber, className, button) {
  const confirmed = window.confirm("Excluir " + className + "? Isso remove os alunos da turma e os links cadastrados para ela. Os registros de frequência já salvos permanecem no histórico geral dos alunos.");
  if (!confirmed) return;

  button.disabled = true;
  button.textContent = "EXCLUINDO...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("delete_teacher_class", { target_class_number: Number(classNumber) });
    if (response.error) throw response.error;
    await renderClasses();
  } catch (error) {
    alert("Não foi possível excluir a turma: " + (error.message || "erro desconhecido") + ". Reexecute supabase_turmas.sql no Supabase.");
    button.disabled = false;
    button.textContent = "EXCLUIR TURMA";
  }
}

function attachDeleteButtons() {
  document.querySelectorAll(".remove-class-button").forEach(function (button) {
    button.addEventListener("click", function () {
      deleteClass(button.dataset.classNumber, button.dataset.className, button);
    });
  });
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
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

  status.textContent = "Professor autenticado: " + currentProfessorSession.user.email + ".";
  document.body.classList.remove("auth-checking");
  await renderClasses();
}

const createClassForm = document.getElementById("createClassForm");
if (createClassForm) createClassForm.addEventListener("submit", createClass);

guardPage();
