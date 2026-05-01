let currentProfessorUser = null;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForProfessorAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

async function guardProfessorHome() {
  const status = document.getElementById("adminStatus");
  const resourcesReady = await waitForProfessorAuthResources();

  if (!resourcesReady) {
    if (status) status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentProfessorUser = await Auth.requireTeacherAdmin("/professor/");
  if (!currentProfessorUser) return;

  if (status) status.textContent = "Professor autenticado: " + currentProfessorUser.email + ".";
  document.body.classList.remove("auth-checking");
}

guardProfessorHome();
