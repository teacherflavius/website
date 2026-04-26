(function () {
  async function save(result) {
    if (!window.Auth || !Auth.saveActivityResult) return;
    try {
      await Auth.saveActivityResult({
        activity_type: result.activity_type || "quiz",
        activity_title: result.activity_title || result.quiz || "Atividade",
        score: result.score,
        total: result.total
      });
    } catch (err) {
      console.warn("Supabase result save failed", err);
    }
  }

  window.SupabaseResults = { save };
})();
