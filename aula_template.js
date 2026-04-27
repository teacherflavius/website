(function () {
  var script = document.currentScript;
  var data = script ? script.dataset : {};

  function buildLink(href, icon, label) {
    var target = href && href !== "#" ? ' target="_blank" rel="noopener noreferrer"' : "";
    return '<a class="menu-button" href="' + href + '"' + target + '><span><span class="icon">' + icon + '</span>' + label + '</span><span class="arrow">›</span></a>';
  }

  function renderLessonPage() {
    var day = data.day || "Aula";
    var time = data.time || "";
    var back = data.back || "links_das_aulas.html";
    var lessonLink = data.lessonLink || "#";
    var materialLink = data.materialLink || "#";
    var whatsappLink = data.whatsappLink || "#";

    document.body.innerHTML =
      '<div class="container">' +
        '<div class="top-links">' +
          '<a class="top-link" href="' + back + '">' + day.toUpperCase() + '</a>' +
          '<a class="top-link" href="links_das_aulas.html">LINKS DAS AULAS</a>' +
        '</div>' +
        '<div class="header">' +
          '<span class="badge">TEACHER FLÁVIO</span>' +
          '<h1>' + day + '<br>' + time + '</h1>' +
        '</div>' +
        '<div class="divider"></div>' +
        '<div class="menu-grid">' +
          buildLink(lessonLink, "▶️", "ASSISTIR A AULA") +
          buildLink(materialLink, "📄", "MATERIAL DA AULA") +
          buildLink(whatsappLink, "💬", "GRUPO DE WHATSAPP") +
        '</div>' +
      '</div>';
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderLessonPage);
  } else {
    renderLessonPage();
  }
})();
