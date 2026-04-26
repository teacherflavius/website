(function () {
  const WHATSAPP_URL = "https://wa.me/5534998349756";
  const MESSAGE = "Agora que você finalizou este quiz, avise o professor";
  const BUTTON_LABEL = "AVISE O PROFESSOR";

  function createNotifyBox() {
    const box = document.createElement("div");
    box.id = "notify-teacher-box";
    box.style.margin = "0 0 18px";
    box.style.padding = "18px";
    box.style.borderRadius = "16px";
    box.style.background = "rgba(129,140,248,0.10)";
    box.style.border = "1px solid rgba(129,140,248,0.35)";

    const message = document.createElement("p");
    message.textContent = MESSAGE;
    message.style.color = "#f1f5f9";
    message.style.fontSize = "15px";
    message.style.lineHeight = "1.5";
    message.style.margin = "0 0 12px";

    const button = document.createElement("a");
    button.href = WHATSAPP_URL;
    button.target = "_blank";
    button.rel = "noopener noreferrer";
    button.textContent = BUTTON_LABEL;
    button.style.display = "inline-flex";
    button.style.justifyContent = "center";
    button.style.alignItems = "center";
    button.style.width = "100%";
    button.style.padding = "14px";
    button.style.borderRadius = "12px";
    button.style.background = "linear-gradient(90deg,#22c55e,#16a34a)";
    button.style.color = "#fff";
    button.style.fontSize = "16px";
    button.style.fontWeight = "bold";
    button.style.fontFamily = "Georgia, serif";
    button.style.textDecoration = "none";

    box.appendChild(message);
    box.appendChild(button);
    return box;
  }

  function injectNotifyButton() {
    if (document.getElementById("notify-teacher-box")) return;

    const headings = Array.from(document.querySelectorAll("h2"));
    const completionHeading = headings.find(function (heading) {
      const text = heading.textContent.trim();
      return text === "Quiz Concluído!" || text === "Exercício concluído!";
    });

    if (!completionHeading) return;

    const retryButton = Array.from(document.querySelectorAll("button")).find(function (button) {
      return button.textContent.trim() === "Tentar novamente";
    });

    if (!retryButton || !retryButton.parentElement) return;

    retryButton.parentElement.insertBefore(createNotifyBox(), retryButton);
  }

  const observer = new MutationObserver(injectNotifyButton);

  function startObserver() {
    const root = document.getElementById("root") || document.getElementById("app") || document.body;
    observer.observe(root, { childList: true, subtree: true });
    injectNotifyButton();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startObserver);
  } else {
    startObserver();
  }
})();
