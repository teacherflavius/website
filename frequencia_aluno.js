let currentSession = null;
let selectedStudent = null;
let editingFrequencyId = null;

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

function getParams() {
  const params = new URLSearchParams(window.location.search);
  return {
    userId: params.get("user_id") || "",
    name: params.get("name") || "Aluno",
    email: params.get("email") || ""
  };
}

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent(window.location.pathname.split("/").pop() + window.location.search);
}

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}

function formatDateInput(value) {
  const digits = String(value || "").replace(/\D/g, "").slice(0, 6);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) return digits.slice(0, 2) + "/" + digits.slice(2);
  return digits.slice(0, 2) + "/" + digits.slice(2, 4) + "/" + digits.slice(4);
}

function parseBrazilianShortDate(value) {
  const match = String(value || "").match(/^(\d{2})\/(\d{2})\/(\d{2})$/);
  if (!match) throw new Error("Informe a data no formato DD/MM/AA.");

  const day = Number(match[1]);
  const month = Number(match[2]);
  const year = 2000 + Number(match[3]);
  const date = new Date(year, month - 1, day);

  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    throw new Error("Data inválida. Use o formato DD/MM/AA.");
  }

  return String(year) + "-" + String(month).padStart(2, "0") + "-" + String(day).padStart(2, "0");
}

function formatDateForDisplay(value) {
  const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!match) return value || "";
  return match[3] + "/" + match[2] + "/" + match[1].slice(2);
}

function setFormMode(mode) {
  const submitButton = document.querySelector('#frequencyForm button[type="submit"]');
  const cancelButton = document.getElementById("cancelEditButton");
  const message = document.getElementById("formMessage");

  if (mode === "edit") {
    if (submitButton) submitButton.textContent = "SALVAR ALTERAÇÕES";
    if (cancelButton) cancelButton.style.display = "inline-flex";
    if (message) {
      message.className = "empty";
      message.textContent = "Editando registro selecionado.";
    }
  } else {
    editingFrequencyId = null;
    if (submitButton) submitButton.textContent = "SALVAR REGISTRO";
    if (cancelButton) cancelButton.style.display = "none";
    if (message) {
      message.className = "empty";
      message.textContent = "";
    }
  }
}

function cancelEdit() {
  document.getElementById("frequencyForm").reset();
  setFormMode("create");
}

async function loadFrequency() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_student_frequency", { target_user_id: selectedStudent.userId });
  if (response.error) throw response.error;
  return response.data || [];
}

function renderHistoryItem(record) {
  const safeId = escapeAttribute(record.id);
  const safeDate = escapeAttribute(formatDateForDisplay(record.class_date));
  const safeStatus = escapeAttribute(record.attendance_status);
  const safeNotes = escapeAttribute(record.class_notes || "");

  return '<div class="student-card">' +
    '<strong>' + escapeHtml(formatDateForDisplay(record.class_date)) + ' — ' + escapeHtml(record.attendance_status) + '</strong>' +
    '<p><b>Lições / observações:</b> ' + escapeHtml(record.class_notes || 'Sem observações.') + '</p>' +
    '<div class="frequency-actions" style="display:flex; gap:8px; flex-wrap:wrap; margin-top:12px;">' +
      '<button type="button" class="edit-frequency-button" data-id="' + safeId + '" data-date="' + safeDate + '" data-status="' + safeStatus + '" data-notes="' + safeNotes + '" style="flex:1; min-width:120px; border:1px solid rgba(129,140,248,0.45); background:rgba(129,140,248,0.10); color:#c4b5fd; border-radius:12px; padding:11px 14px; font-family:Georgia,serif; font-size:13px; font-weight:bold; cursor:pointer; letter-spacing:0.4px;">EDITAR</button>' +
      '<button type="button" class="delete-frequency-button" data-id="' + safeId + '" style="flex:1; min-width:120px; border:1px solid rgba(248,113,113,0.45); background:rgba(248,113,113,0.10); color:#fca5a5; border-radius:12px; padding:11px 14px; font-family:Georgia,serif; font-size:13px; font-weight:bold; cursor:pointer; letter-spacing:0.4px;">APAGAR</button>' +
    '</div>' +
  '</div>';
}

function attachHistoryActions() {
  document.querySelectorAll(".edit-frequency-button").forEach(function (button) {
    button.addEventListener("click", function () {
      editingFrequencyId = button.dataset.id;
      document.getElementById("classDate").value = button.dataset.date || "";
      document.getElementById("attendanceStatus").value = button.dataset.status || "Compareceu";
      document.getElementById("classNotes").value = button.dataset.notes || "";
      setFormMode("edit");
      document.getElementById("frequencyForm").scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });

  document.querySelectorAll(".delete-frequency-button").forEach(function (button) {
    button.addEventListener("click", function () {
      deleteFrequency(button.dataset.id, button);
    });
  });
}

async function renderFrequencyHistory() {
  const list = document.getElementById("frequencyList");
  try {
    const records = await loadFrequency();
    if (!records.length) {
      list.className = "empty";
      list.textContent = "Nenhum registro de frequência cadastrado para este aluno.";
      return;
    }
    list.className = "";
    list.innerHTML = records.map(renderHistoryItem).join("");
    attachHistoryActions();
  } catch (error) {
    list.className = "error";
    list.textContent = "Não foi possível carregar a frequência: " + (error.message || "erro desconhecido") + ". Execute supabase_frequencia_professor.sql no Supabase.";
  }
}

async function saveFrequency(event) {
  event.preventDefault();
  const message = document.getElementById("formMessage");
  const wasEditing = !!editingFrequencyId;
  message.className = "empty";
  message.textContent = wasEditing ? "Salvando alterações..." : "Salvando...";

  try {
    const classDateInput = document.getElementById("classDate").value;
    const classDate = parseBrazilianShortDate(classDateInput);
    const attendanceStatus = document.getElementById("attendanceStatus").value;
    const classNotes = document.getElementById("classNotes").value.trim();

    const client = Auth.getClient();
    const rpcName = wasEditing ? "update_teacher_student_frequency" : "save_teacher_student_frequency";
    const payload = wasEditing ? {
      target_frequency_id: editingFrequencyId,
      target_class_date: classDate,
      target_attendance_status: attendanceStatus,
      target_class_notes: classNotes
    } : {
      target_user_id: selectedStudent.userId,
      target_class_date: classDate,
      target_attendance_status: attendanceStatus,
      target_class_notes: classNotes
    };

    const response = await client.rpc(rpcName, payload);
    if (response.error) throw response.error;

    document.getElementById("frequencyForm").reset();
    setFormMode("create");
    message.className = "empty";
    message.textContent = wasEditing ? "Registro atualizado." : "Registro salvo.";
    await renderFrequencyHistory();
  } catch (error) {
    message.className = "error";
    message.textContent = error.message || "Não foi possível salvar o registro.";
  }
}

async function deleteFrequency(frequencyId, button) {
  const confirmed = window.confirm("Tem certeza que deseja apagar este registro de frequência?");
  if (!confirmed) return;

  button.disabled = true;
  button.textContent = "APAGANDO...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("delete_teacher_student_frequency", {
      target_frequency_id: frequencyId
    });
    if (response.error) throw response.error;

    if (editingFrequencyId === frequencyId) cancelEdit();
    await renderFrequencyHistory();
  } catch (error) {
    alert("Não foi possível apagar o registro: " + (error.message || "erro desconhecido") + ". Reexecute o SQL atualizado no Supabase.");
    button.disabled = false;
    button.textContent = "APAGAR";
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  selectedStudent = getParams();

  document.getElementById("studentName").textContent = selectedStudent.name;
  document.getElementById("studentEmail").textContent = selectedStudent.email || "E-mail não informado";

  if (!selectedStudent.userId) {
    status.textContent = "Aluno não informado.";
    document.body.classList.remove("auth-checking");
    return;
  }

  const resourcesReady = await waitForAuthResources();
  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentSession = await Auth.getSession();
  if (!currentSession || !currentSession.user) {
    redirectToLogin();
    return;
  }

  status.textContent = "Professor autenticado: " + currentSession.user.email + ".";
  document.body.classList.remove("auth-checking");
  await renderFrequencyHistory();
}

const classDateInput = document.getElementById("classDate");
if (classDateInput) {
  classDateInput.addEventListener("input", function () {
    this.value = formatDateInput(this.value);
  });
}

const cancelEditButton = document.getElementById("cancelEditButton");
if (cancelEditButton) cancelEditButton.addEventListener("click", cancelEdit);

document.getElementById("frequencyForm").addEventListener("submit", saveFrequency);
guardPage();
