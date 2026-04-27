let currentSession = null;

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("area_do_estudante.html");
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

async function guardStudentArea() {
  const status = document.getElementById("loginStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    document.body.classList.remove("auth-checking");
    if (status) status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    return false;
  }

  currentSession = await Auth.getSession();

  if (!currentSession || !currentSession.user) {
    redirectToLogin();
    return false;
  }

  document.body.classList.remove("auth-checking");
  return true;
}

async function updateStatus() {
  const isAllowed = await guardStudentArea();
  if (!isAllowed) return;

  const status = document.getElementById("loginStatus");
  const profile = await Auth.getProfile();
  status.textContent = `Logado como ${profile && profile.name ? profile.name : currentSession.user.email}.`;
}

updateStatus();
