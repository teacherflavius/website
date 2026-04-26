(function () {
  const STUDENT_KEY = "teacher_flavio_current_student";

  function readJson(key, fallback) {
    try { return JSON.parse(localStorage.getItem(key)) || fallback; }
    catch (_) { return fallback; }
  }

  function writeJson(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  function getCurrentStudent() {
    return readJson(STUDENT_KEY, null);
  }

  function setCurrentStudent(student) {
    writeJson(STUDENT_KEY, student);
  }

  function clearCurrentStudent() {
    localStorage.removeItem(STUDENT_KEY);
  }

  function getResults() {
    return [];
  }

  function resultsToCsv() {
    return "Data,Nome,Email,Atividade,Acertos,Total,Percentual\n";
  }

  function downloadCsv() {
    alert("Os resultados agora são salvos apenas no Supabase. Consulte o histórico em perfil.html.");
  }

  async function saveResult(result) {
    const completeResult = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2),
      date: new Date().toISOString(),
      name: result.name,
      email: result.email,
      quiz: result.quiz,
      score: Number(result.score),
      total: Number(result.total),
      percentage: Math.round((Number(result.score) / Number(result.total)) * 100),
      activity_type: result.activity_type || "quiz"
    };

    if (window.SupabaseResults && typeof window.SupabaseResults.save === "function") {
      await window.SupabaseResults.save({
        activity_type: completeResult.activity_type,
        activity_title: completeResult.quiz,
        score: completeResult.score,
        total: completeResult.total
      });
    } else if (window.Auth && typeof window.Auth.saveActivityResult === "function") {
      await window.Auth.saveActivityResult({
        activity_type: completeResult.activity_type,
        activity_title: completeResult.quiz,
        score: completeResult.score,
        total: completeResult.total
      });
    } else {
      console.warn("Supabase não está disponível. Resultado não salvo.");
    }

    return completeResult;
  }

  function addBaseStyles() {
    if (document.getElementById("quiz-core-styles")) return;
    const style = document.createElement("style");
    style.id = "quiz-core-styles";
    style.textContent = `
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
      body { min-height: 100vh; background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #0f172a 100%); display: flex; flex-direction: column; align-items: center; padding: 32px 16px 48px; font-family: Georgia, serif; }
      @keyframes fadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
      @keyframes shake { 0%,100% { transform: translateX(0); } 25% { transform: translateX(-8px); } 75% { transform: translateX(8px); } }
      .shake { animation: shake 0.4s ease; }
      .fade-in { animation: fadeIn 0.3s ease; }
      .btn-back { display: inline-flex; align-items: center; gap: 8px; background: rgba(255,255,255,0.05); border: 1.5px solid rgba(129,140,248,0.35); border-radius: 10px; padding: 9px 18px; color: #818cf8; font-size: 14px; font-family: Georgia, serif; text-decoration: none; transition: background 0.2s, border-color 0.2s, transform 0.2s; cursor: pointer; }
      .btn-back:hover { background: rgba(129,140,248,0.12); border-color: #818cf8; transform: translateY(-1px); }
      .option-btn { transition: transform 0.2s, border-color 0.2s !important; }
      .option-btn:hover { transform: translateY(-2px); border-color: #818cf8 !important; }
      .btn-primary:hover { opacity: 0.88 !important; transform: translateY(-1px); }
      input { width: 100%; background: rgba(255,255,255,0.06); border: 1.5px solid rgba(255,255,255,0.12); border-radius: 12px; padding: 13px 14px; color: #f1f5f9; font-size: 15px; font-family: Georgia, serif; margin-bottom: 12px; }
      input:focus { outline: none; border-color: #818cf8; }
      label { color: #cbd5e1; font-size: 13px; line-height: 1.5; }
    `;
    document.head.appendChild(style);
  }

  function e() {
    return React.createElement.apply(React, arguments);
  }

  function Button(props) {
    return e("button", Object.assign({
      className: "btn-primary",
      style: { width: "100%", padding: 14, borderRadius: 12, border: "none", background: "linear-gradient(90deg,#818cf8,#a78bfa)", color: "#fff", fontSize: 16, fontWeight: "bold", cursor: "pointer", fontFamily: "Georgia, serif" }
    }, props), props.children);
  }

  function Header(props) {
    return e("div", { style: { textAlign: "center", marginBottom: 24 } },
      e("div", { style: { display: "inline-block", background: "linear-gradient(90deg,#818cf8,#a78bfa)", color: "#fff", fontSize: 11, fontFamily: "monospace", letterSpacing: 3, padding: "4px 14px", borderRadius: 20, marginBottom: 12 } }, "TEACHER FLÁVIO"),
      e("h1", { style: { color: "#f1f5f9", fontSize: props.small ? 28 : 32, marginBottom: props.subtitle ? 6 : 0, fontWeight: "bold", letterSpacing: -1 } }, props.title),
      props.subtitle ? e("p", { style: { color: "#94a3b8", fontSize: 14, fontStyle: "italic" } }, props.subtitle) : null
    );
  }

  function ParticipantForm(props) {
    const useState = React.useState;
    const [form, setForm] = useState({ name: "", email: "", consent: false });
    const [error, setError] = useState("");

    function update(field, value) {
      setForm(Object.assign({}, form, { [field]: value }));
    }

    function submit(event) {
      event.preventDefault();
      const name = form.name.trim();
      const email = form.email.trim();
      if (!name || !email) return setError("Preencha seu nome e seu e-mail antes de começar.");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return setError("Insira um e-mail válido.");
      if (!form.consent) return setError("Marque a autorização para registrar seu desempenho.");
      const student = { name, email };
      setCurrentStudent(student);
      props.onSubmit(student);
    }

    return e("div", { style: { width: "100%", maxWidth: 520 } },
      e("div", { style: { marginBottom: 20 } }, e("a", { href: "index.html", className: "btn-back" }, "INÍCIO")),
      e(Header, { title: props.quizTitle, subtitle: "Identificação do aluno" }),
      e("form", { onSubmit: submit, style: { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 20, padding: "28px", backdropFilter: "blur(12px)" } },
        e("p", { style: { color: "#94a3b8", fontSize: 14, lineHeight: 1.6, marginBottom: 18 } }, "Antes de responder ao quiz, informe seus dados para que seu desempenho seja registrado no Supabase."),
        e("input", { type: "text", placeholder: "Nome completo", value: form.name, onChange: function (ev) { update("name", ev.target.value); } }),
        e("input", { type: "email", placeholder: "E-mail", value: form.email, onChange: function (ev) { update("email", ev.target.value); } }),
        e("label", { style: { display: "flex", gap: 10, alignItems: "flex-start", margin: "4px 0 16px" } },
          e("input", { type: "checkbox", checked: form.consent, onChange: function (ev) { update("consent", ev.target.checked); }, style: { width: 18, marginTop: 2, marginBottom: 0 } }),
          e("span", null, "Autorizo o registro do meu nome, e-mail e desempenho neste quiz.")
        ),
        error ? e("p", { style: { color: "#fca5a5", fontSize: 13, marginBottom: 14 } }, error) : null,
        e(Button, { type: "submit" }, "Começar quiz")
      )
    );
  }

  async function applyLoggedStudentIfAvailable() {
    if (!window.Auth || !Auth.isConfigured || !Auth.isConfigured()) return null;
    const user = await Auth.requireAuth();
    if (!user) return null;
    const profile = await Auth.getProfile();
    const student = {
      name: profile && profile.name ? profile.name : "Aluno",
      email: profile && profile.email ? profile.email : user.email
    };
    setCurrentStudent(student);
    return student;
  }

  function renderQuiz(config) {
    addBaseStyles();
    const root = document.getElementById("root");
    root.innerHTML = '<p style="color:#94a3b8;font-family:Georgia,serif;text-align:center;margin-top:40px;">Carregando atividade...</p>';
    applyLoggedStudentIfAvailable().then(function () { startQuiz(config); });
  }

  function startQuiz(config) {
    const root = document.getElementById("root");
    const questions = config.questions;
    const total = questions.length;

    function App() {
      const useState = React.useState;
      const useEffect = React.useEffect;
      const [student, setStudent] = useState(getCurrentStudent());
      const [current, setCurrent] = useState(0);
      const [selected, setSelected] = useState(null);
      const [confirmed, setConfirmed] = useState(false);
      const [score, setScore] = useState(0);
      const [finished, setFinished] = useState(false);
      const [saved, setSaved] = useState(false);
      const [shake, setShake] = useState(false);

      useEffect(function () {
        if (finished && !saved && student) {
          saveResult({ name: student.name, email: student.email, quiz: config.title, score: score, total: total, activity_type: "quiz" });
          setSaved(true);
        }
      }, [finished, saved, student, score]);

      if (!student) return e(ParticipantForm, { quizTitle: config.title, onSubmit: setStudent });

      const q = questions[current];
      const progress = finished ? 100 : (current / total) * 100;
      const isCorrect = selected === (q && q.answer);

      function optionStyle(opt) {
        const base = { background: "rgba(255,255,255,0.05)", border: "1.5px solid rgba(255,255,255,0.1)", borderRadius: 12, padding: "14px 18px", textAlign: "left", cursor: "pointer", color: "#cbd5e1", fontSize: 16, width: "100%", fontFamily: "Georgia, serif", marginBottom: 10 };
        if (confirmed) {
          if (opt === q.answer) return Object.assign({}, base, { background: "rgba(110,231,183,0.15)", border: "1.5px solid #6ee7b7", color: "#d1fae5", cursor: "default" });
          if (opt === selected) return Object.assign({}, base, { background: "rgba(252,165,165,0.15)", border: "1.5px solid #fca5a5", color: "#fee2e2", cursor: "default" });
          return Object.assign({}, base, { opacity: 0.35, cursor: "default" });
        }
        if (opt === selected) return Object.assign({}, base, { background: "rgba(129,140,248,0.15)", border: "1.5px solid #818cf8", color: "#e0e7ff" });
        return base;
      }

      function confirm() {
        if (!selected) { setShake(true); setTimeout(function () { setShake(false); }, 500); return; }
        setConfirmed(true);
        if (selected === q.answer) setScore(function (s) { return s + 1; });
      }

      function next() {
        if (current + 1 >= total) setFinished(true);
        else { setCurrent(function (c) { return c + 1; }); setSelected(null); setConfirmed(false); }
      }

      function restart() {
        setCurrent(0); setSelected(null); setConfirmed(false); setScore(0); setFinished(false); setSaved(false);
      }

      function feedback() {
        const pct = (score / total) * 100;
        if (pct === 100) return { emoji: "🏆", msg: config.feedbackPerfect || "Perfeito!" };
        if (pct >= 75) return { emoji: "🌟", msg: "Muito bom. Continue praticando." };
        if (pct >= 50) return { emoji: "📚", msg: "Bom esforço. Revise as regras e tente novamente." };
        return { emoji: "💪", msg: "Continue praticando. Você vai melhorar." };
      }

      return e("div", { style: { width: "100%", maxWidth: 520 } },
        e("div", { style: { marginBottom: 20 } },
          e("a", { href: "index.html", className: "btn-back" }, "INÍCIO")
        ),
        e(Header, { title: config.title, subtitle: config.subtitle, small: config.smallTitle }),
        e("div", { style: { height: 4, background: "#1e293b", borderRadius: 99, marginBottom: 28, overflow: "hidden" } },
          e("div", { style: { height: "100%", background: "linear-gradient(90deg,#818cf8,#a78bfa)", borderRadius: 99, width: progress + "%", transition: "width 0.5s ease" } })
        ),
        !finished ? e("div", { className: shake ? "shake" : "", style: { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 20, padding: "32px 28px", backdropFilter: "blur(12px)" } },
          e("div", { style: { marginBottom: 16 } }, e("span", { style: { fontSize: 28, fontWeight: "bold", color: "#a78bfa" } }, current + 1), e("span", { style: { fontSize: 18, color: "#475569" } }, " / " + total)),
          e("p", { style: { color: "#f1f5f9", fontSize: 22, lineHeight: 1.5, marginBottom: 28, fontWeight: "bold" } }, q.question),
          e("div", null, q.options.map(function (opt) { return e("button", { key: opt, className: "option-btn", style: optionStyle(opt), onClick: function () { if (!confirmed) setSelected(opt); } }, opt); })),
          confirmed ? e("div", { className: "fade-in", style: { display: "flex", gap: 12, alignItems: "flex-start", background: isCorrect ? "rgba(110,231,183,0.07)" : "rgba(252,165,165,0.07)", border: "1px solid " + (isCorrect ? "#6ee7b7" : "#fca5a5"), borderRadius: 12, padding: "14px 16px", marginBottom: 20 } },
            e("span", { style: { fontSize: 18 } }, isCorrect ? "✅" : "❌"),
            e("p", { style: { margin: 0, color: "#e2e8f0", fontSize: 14, lineHeight: 1.6 } }, e("strong", null, isCorrect ? "Correto! " : "Errado. A resposta é \"" + q.answer + "\". "), q.explanation)
          ) : null,
          e("div", { style: { marginBottom: 16 } }, !confirmed ? e(Button, { onClick: confirm }, "Confirmar") : e(Button, { onClick: next }, current + 1 >= total ? "Ver resultado →" : "Próxima →")),
          e("div", { style: { textAlign: "center", color: "#94a3b8", fontSize: 14 } }, "⭐ " + score + " acerto" + (score !== 1 ? "s" : ""))
        ) : e("div", { style: { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 20, padding: "32px 28px", textAlign: "center" } },
          e("div", { style: { fontSize: 56, marginBottom: 12 } }, feedback().emoji),
          e("h2", { style: { color: "#f1f5f9", fontSize: 26, marginBottom: 20 } }, "Quiz Concluído!"),
          e("p", { style: { color: "#94a3b8", fontSize: 14, marginBottom: 8 } }, student.name + " · " + student.email),
          e("div", { style: { marginBottom: 16 } }, e("span", { style: { fontSize: 52, fontWeight: "bold", color: "#a78bfa" } }, score), e("span", { style: { fontSize: 28, color: "#475569" } }, " / " + total)),
          e("p", { style: { color: "#94a3b8", fontSize: 15, marginBottom: 20, lineHeight: 1.6 } }, feedback().msg),
          e("p", { style: { color: "#6ee7b7", fontSize: 13, marginBottom: 24 } }, saved ? "Resultado enviado ao Supabase." : "Enviando resultado ao Supabase..."),
          e(Button, { onClick: restart }, "Tentar novamente")
        )
      );
    }

    ReactDOM.createRoot(root).render(e(App));
  }

  window.QuizCore = {
    renderQuiz,
    getResults,
    downloadCsv,
    resultsToCsv,
    clearCurrentStudent,
    getCurrentStudent,
    setCurrentStudent,
    saveResult
  };
})();
