(function () {
  async function start() {
    if (!window.Auth) return;
    const user = await Auth.requireAuth();
    if (!user) return;
    const profile = await Auth.getProfile();
    const displayName = profile && profile.name ? profile.name : "Aluno";
    const displayEmail = profile && profile.email ? profile.email : user.email;
    if (window.QuizCore && QuizCore.setCurrentStudent) {
      QuizCore.setCurrentStudent({ name: displayName, email: displayEmail });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
