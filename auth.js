(function () {
  function isConfigured() {
    return window.SUPABASE_CONFIG &&
      window.SUPABASE_CONFIG.url &&
      window.SUPABASE_CONFIG.anonKey &&
      !window.SUPABASE_CONFIG.url.includes("COLE_AQUI") &&
      !window.SUPABASE_CONFIG.anonKey.includes("COLE_AQUI");
  }

  function getClient() {
    if (!isConfigured()) return null;
    if (!window.supabase || !window.supabase.createClient) return null;
    if (!window.teacherFlavioSupabase) {
      window.teacherFlavioSupabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );
    }
    return window.teacherFlavioSupabase;
  }

  function getRedirectUrl() {
    return new URL("login.html", window.location.href).href;
  }

  function showConfigWarning() {
    if (document.getElementById("supabase-config-warning")) return;
    const warning = document.createElement("div");
    warning.id = "supabase-config-warning";
    warning.style.position = "fixed";
    warning.style.left = "12px";
    warning.style.right = "12px";
    warning.style.bottom = "12px";
    warning.style.zIndex = "20000";
    warning.style.background = "rgba(251,191,36,0.12)";
    warning.style.border = "1px solid rgba(251,191,36,0.35)";
    warning.style.color = "#fde68a";
    warning.style.borderRadius = "12px";
    warning.style.padding = "12px 14px";
    warning.style.fontFamily = "Georgia, serif";
    warning.style.fontSize = "13px";
    warning.style.lineHeight = "1.5";
    warning.textContent = "Supabase ainda não configurado. Edite supabase_config.js com a URL e a chave pública anon do seu projeto.";
    document.body.appendChild(warning);
  }

  function generateEnrollmentCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 5; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
  }

  function normalizeCpf(cpf) {
    return String(cpf || "").replace(/\D/g, "");
  }

  function normalizeWhatsapp(whatsapp) {
    return String(whatsapp || "").replace(/\D/g, "");
  }

  function normalizePixKey(pixKey) {
    return String(pixKey || "").trim();
  }

  function normalizeAvailability(availability) {
    const days = ["seg", "ter", "qua", "qui", "sex"];
    const hours = ["09", "10", "12", "13", "15", "17", "18", "20", "21"];
    const normalized = {};

    days.forEach(function (day) {
      const selected = Array.isArray(availability && availability[day]) ? availability[day] : [];
      normalized[day] = selected.filter(function (hour) {
        return hours.includes(hour);
      });
    });

    return normalized;
  }

  function countAvailabilitySlots(availability) {
    return Object.keys(availability || {}).reduce(function (total, day) {
      return total + (Array.isArray(availability[day]) ? availability[day].length : 0);
    }, 0);
  }

  function availabilityToProfileColumns(availability) {
    const days = ["seg", "ter", "qua", "qui", "sex"];
    const hours = ["09", "10", "12", "13", "15", "17", "18", "20", "21"];
    const columns = {};

    days.forEach(function (day) {
      hours.forEach(function (hour) {
        columns["availability_" + day + "_" + hour] = Array.isArray(availability[day]) && availability[day].includes(hour);
      });
    });

    return columns;
  }

  async function getSession() {
    const client = getClient();
    if (!client) return null;
    const response = await client.auth.getSession();
    return response && response.data ? response.data.session : null;
  }

  async function getUser() {
    const client = getClient();
    if (!client) return null;
    const response = await client.auth.getUser();
    return response && response.data ? response.data.user : null;
  }

  async function requireAuth() {
    if (!isConfigured()) {
      showConfigWarning();
      return null;
    }
    const session = await getSession();
    if (!session) {
      const next = encodeURIComponent(window.location.pathname.split("/").pop() || "index.html");
      window.location.href = "login.html?next=" + next;
      return null;
    }
    return session.user;
  }

  async function signUp(name, email, password) {
    const client = getClient();
    if (!client) throw new Error("Supabase não configurado.");
    const response = await client.auth.signUp({
      email: email,
      password: password,
      options: {
        data: { name: name },
        emailRedirectTo: getRedirectUrl()
      }
    });
    if (response.error) throw response.error;

    if (response.data && response.data.user) {
      await client.from("profiles").upsert({
        id: response.data.user.id,
        name: name,
        email: email
      });
    }
    return response.data;
  }

  async function enrollStudent(data) {
    const client = getClient();
    if (!client) throw new Error("Supabase não configurado.");

    const enrollmentCode = generateEnrollmentCode();
    const cleanCpf = normalizeCpf(data.cpf);
    const cleanWhatsapp = normalizeWhatsapp(data.whatsapp);
    const pixKey = normalizePixKey(data.pix_key);
    const availability = normalizeAvailability(data.availability);
    const availabilityColumns = availabilityToProfileColumns(availability);

    if (!data.name || !data.email || !data.password || !cleanCpf || !cleanWhatsapp || !pixKey) {
      throw new Error("Preencha todos os campos da matrícula.");
    }

    if (cleanCpf.length !== 11) {
      throw new Error("CPF inválido. Informe 11 dígitos.");
    }

    if (cleanWhatsapp.length < 10) {
      throw new Error("WhatsApp inválido.");
    }

    if (countAvailabilitySlots(availability) === 0) {
      throw new Error("Selecione pelo menos um horário disponível para aulas durante a semana.");
    }

    const enrollmentMetadata = {
      name: data.name,
      cpf: cleanCpf,
      whatsapp: cleanWhatsapp,
      pix_key: pixKey,
      availability: availability,
      enrollment_code: enrollmentCode,
      enrolled: true
    };

    const response = await client.auth.signUp({
      email: data.email,
      password: data.password,
      options: {
        data: enrollmentMetadata,
        emailRedirectTo: getRedirectUrl()
      }
    });

    if (response.error) throw response.error;

    if (response.data && response.data.user) {
      const userId = response.data.user.id;

      const profilePayload = Object.assign({
        id: userId,
        name: data.name,
        email: data.email,
        cpf: cleanCpf,
        whatsapp: cleanWhatsapp,
        pix_key: pixKey,
        availability: availability,
        enrollment_code: enrollmentCode,
        enrolled: true
      }, availabilityColumns);

      const basicProfileResponse = await client.from("profiles").upsert(profilePayload).select().single();

      if (basicProfileResponse.error) {
        console.warn("Não foi possível atualizar profiles com os dados de matrícula:", basicProfileResponse.error.message);
      }

      
    l

    return {
      user: response.data ? response.data.user : null,
      enrollment_code: enrollmentCode
    };
  }

  async function signIn(email, password) {
    const client = getClient();
    if (!client) throw new Error("Supabase não configurado.");
    const response = await client.auth.signInWithPassword({ email: email, password: password });
    if (response.error) throw response.error;
    return response.data;
  }

  async function signOut() {
    const client = getClient();
    if (!client) return;
    await client.auth.signOut();
    window.location.href = "login.html";
  }

  async function getProfile() {
    const client = getClient();
    const user = await getUser();
    if (!client || !user) return null;
    const response = await client.from("profiles").select("*").eq("id", user.id).single();
    const fallbackProfile = {
      id: user.id,
      name: user.user_metadata && user.user_metadata.name || "",
      email: user.email,
      cpf: user.user_metadata && user.user_metadata.cpf || "",
      whatsapp: user.user_metadata && user.user_metadata.whatsapp || "",
      pix_key: user.user_metadata && user.user_metadata.pix_key || "",
      availability: user.user_metadata && user.user_metadata.availability || {},
      enrollment_code: user.user_metadata && user.user_metadata.enrollment_code || "",
      enrolled: user.user_metadata && user.user_metadata.enrolled || false
    };
    if (response.error) return fallbackProfile;
    return Object.assign({}, fallbackProfile, response.data);
  }

  async function saveActivityResult(result) {
    const client = getClient();
    const user = await getUser();
    if (!client || !user) return null;

    const payload = {
      user_id: user.id,
      activity_type: result.activity_type || result.type || "activity",
      activity_title: result.activity_title || result.quiz || result.title,
      score: Number(result.score),
      total: Number(result.total),
      percentage: Math.round((Number(result.score) / Number(result.total)) * 100),
      completed_at: new Date().toISOString()
    };

    const response = await client.from("activity_results").insert(payload).select().single();
    if (response.error) {
      console.warn("Erro ao salvar no Supabase:", response.error.message);
      return null;
    }
    return response.data;
  }

  async function getMyResults() {
    const client = getClient();
    const user = await getUser();
    if (!client || !user) return [];
    const response = await client
      .from("activity_results")
      .select("*")
      .eq("user_id", user.id)
      .order("completed_at", { ascending: false });
    if (response.error) return [];
    return response.data || [];
  }

  window.Auth = {
    isConfigured,
    getClient,
    showConfigWarning,
    generateEnrollmentCode,
    getSession,
    getUser,
    requireAuth,
    signUp,
    enrollStudent,
    signIn,
    signOut,
    getProfile,
    saveActivityResult,
    getMyResults
  };
})();
