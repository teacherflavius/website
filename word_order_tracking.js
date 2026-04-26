(function () {
  const EXERCISE_TITLE = "Ordenar Frases - Simple Present";
  const TOTAL = 10;
  let saved = false;

  function getStudent() {
    if (!window.QuizCore || !QuizCore.getCurrentStudent) return null;
    return QuizCore.getCurrentStudent();
  }

  function validEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  function createGate() {
    if (document.getElementById("student-gate")) return;
    const currentStudent = getStudent() || { name: "", email: "" };

    const gate = document.createElement("div");
    gate.id = "student-gate";
    gate.style.position = "fixed";
    gate.style.inset = "0";
    gate.style.zIndex = "10000";
    gate.style.background = "linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #0f172a 100%)";
    gate.style.display = "flex";
    gate.style.alignItems = "center";
    gate.style.justifyContent = "center";
    gate.style.padding = "32px 16px";
    gate.style.fontFamily = "Georgia, serif";

    gate.innerHTML = `
      <form id="student-gate-form" style="width:100%;max-width:520px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:20px;padding:28px;backdrop-filter:blur(12px);">
        <div style="text-align:center;margin-bottom:24px;">
          <div style="display:inline-block;background:linear-gradient(90deg,#818cf8,#a78bfa);color:#fff;font-size:11px;font-family:monospace;letter-spacing:3px;padding:4px 14px;border-radius:20px;margin-bottom:12px;">TEACHER FLÁVIO</div>
          <h1 style="color:#f1f5f9;font-size:30px;margin-bottom:8px;letter-spacing:-1px;">Identificação do aluno</h1>
          <p style="color:#94a3b8;font-size:14px;line-height:1.6;">Antes de começar, informe seus dados para que seu desempenho seja registrado.</p>
        </div>
        <input id="student-gate-name" type="text" placeholder="Nome completo" value="${escapeHtml(currentStudent.name || "")}" style="width:100%;background:rgba(255,255,255,0.06);border:1.5px solid rgba(255,255,255,0.12);border-radius:12px;padding:13px 14px;color:#f1f5f9;font-size:15px;font-family:Georgia,serif;margin-bottom:12px;" />
        <input id="student-gate-email" type="email" placeholder="E-mail" value="${escapeHtml(currentStudent.email || "")}" style="width:100%;background:rgba(255,255,255,0.06);border:1.5px solid rgba(255,255,255,0.12);border-radius:12px;padding:13px 14px;color:#f1f5f9;font-size:15px;font-family:Georgia,serif;margin-bottom:12px;" />
        <label style="display:flex;gap:10px;align-items:flex-start;margin:4px 0 16px;color:#cbd5e1;font-size:13px;line-height:1.5;">
          <input id="student-gate-consent" type="checkbox" style="width:18px;margin-top:2px;" />
          <span>Autorizo o registro do meu nome, e-mail e desempenho neste exercício.</span>
        </label>
        <p id="student-gate-error" style="min-height:18px;color:#fca5a5;font-size:13px;margin-bottom:14px;"></p>
        <button type="submit" style="width:100%;padding:14px;border-radius:12px;border:none;background:linear-gradient(90deg,#818cf8,#a78bfa);color:#fff;font-size:16px;font-weight:bold;cursor:pointer;font-family:Georgia,serif;">Começar exercício</button>
      </form>
    `;

    document.body.appendChild(gate);

    document.getElementById("student-gate-form").addEventListener("submit", function (event) {
      event.preventDefault();
      const name = document.getElementById("student-gate-name").value.trim();
      const email = document.getElementById("student-gate-email").value.trim();
      const consent = document.getElementById("student-gate-consent").checked;
      const error = document.getElementById("student-gate-error");

      if (!name || !email) {
        error.textContent = "Preencha seu nome e seu e-mail antes de começar.";
        return;
      }
      if (!validEmail(email)) {
        error.textContent = "Insira um e-mail válido.";
        return;
      }
      if (!consent) {
        error.textContent = "Marque a autorização para registrar seu desempenho.";
        return;
      }

      QuizCore.setCurrentStudent({ name, email });
      gate.remove();
    });
  }

  function detectAndSaveResult() {
    if (saved || !window.QuizCore || !QuizCore.saveResult) return;

    const heading = Array.from(document.querySelectorAll("h2")).find(function (h2) {
      return h2.textContent.trim() === "Exercício concluído!";
    });
    if (!heading) return;

    const student = getStudent();
    if (!student || !student.name || !student.email) return;

    const scoreTextNode = Array.from(document.querySelectorAll("p")).find(function (p) {
      return /Você acertou \d+ de \d+ frases\./.test(p.textContent.trim());
    });
    if (!scoreTextNode) return;

    const match = scoreTextNode.textContent.match(/Você acertou (\d+) de (\d+) frases\./);
    if (!match) return;

    const score = Number(match[1]);
    const total = Number(match[2] || TOTAL);
    saved = true;

    QuizCore.saveResult({
      name: student.name,
      email: student.email,
      quiz: EXERCISE_TITLE,
      score: score,
      total: total,
      activity_type: "word_order"
    });

    if (!document.getElementById("word-order-saved-message")) {
      const message = document.createElement("p");
      message.id = "word-order-saved-message";
      message.textContent = "Resultado registrado.";
      message.style.color = "#6ee7b7";
      message.style.fontSize = "13px";
      message.style.marginBottom = "18px";
      scoreTextNode.insertAdjacentElement("afterend", message);
    }
  }

  function escapeHtml(value) {
    return String(value || "").replace(/[&<>"]/g, function (char) {
      return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" })[char];
    });
  }

  function init() {
    if (!getStudent()) createGate();
    const observer = new MutationObserver(detectAndSaveResult);
    observer.observe(document.getElementById("app") || document.body, { childList: true, subtree: true });
    detectAndSaveResult();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
