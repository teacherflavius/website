(function () {
  async function start() {
    if (!window.Auth || !window.QuizCore) return;
    const user = await Auth.requireAuth();
    if (!user) return;
    const profile = await Auth.getProfile();
    QuizCore.setCurrentStudent({
      name: profile && profile.name ? profile.name : "Aluno",
      email: profile && profile.email ? profile.email : user.email
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
