const PROFESSOR_ADMIN_EMAIL = "flaviofreitas@ufu.br";

async function getCurrentHomeUser() {
  if (!window.Auth || !Auth.isConfigured()) return null;
  const session = await Auth.getSession();
  return session && session.user ? session.user : await Auth.getUser();
}

async function shouldHideEnrollmentCard() {
  const user = await getCurrentHomeUser();
  if (!user) return false;

  const metadata = user.user_metadata || {};
  if (metadata.enrolled === true || metadata.enrolled === "true" || metadata.enrollment_code) return true;

  const profile = await Auth.getProfile();
  return !!(profile && (profile.enrolled === true || profile.enrolled === "true" || profile.enrollment_code));
}

async function updateEnrollmentCardVisibility() {
  const enrollmentCard = document.getElementById("enrollmentCard");
  if (!enrollmentCard) return;

  try {
    const hideCard = await shouldHideEnrollmentCard();
    enrollmentCard.classList.toggle("hidden", hideCard);
  } catch (error) {
    console.warn("Não foi possível verificar a matrícula do usuário:", error);
    enrollmentCard.classList.remove("hidden");
  }
}

async function updateProfessorAdminLinkVisibility() {
  const professorAdminLink = document.getElementById("professorAdminLink");
  if (!professorAdminLink) return;

  professorAdminLink.style.display = "none";

  try {
    const user = await getCurrentHomeUser();
    const email = user && user.email ? user.email.toLowerCase() : "";
    if (email === PROFESSOR_ADMIN_EMAIL) {
      professorAdminLink.style.display = "";
    }
  } catch (error) {
    console.warn("Não foi possível verificar o usuário professor:", error);
    professorAdminLink.style.display = "none";
  }
}

async function updateHomeVisibility() {
  await updateEnrollmentCardVisibility();
  await updateProfessorAdminLinkVisibility();
}

document.addEventListener("DOMContentLoaded", updateHomeVisibility);

if (window.Auth && Auth.isConfigured()) {
  const client = Auth.getClient();
  if (client && client.auth && client.auth.onAuthStateChange) {
    client.auth.onAuthStateChange(function () {
      updateHomeVisibility();
    });
  }
}
