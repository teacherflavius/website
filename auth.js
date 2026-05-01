(function () {
  function loadAnimatedCardsAssets() {
    function inject() {
      if (!document.querySelector('link[href^="animated_cards.css"]')) {
        const link = document.createElement("link");
        link.rel = "stylesheet";
        link.href = "animated_cards.css?v=20260427-3";
        document.head.appendChild(link);
      }

      if (!document.querySelector('script[src^="animated_cards.js"]')) {
        const script = document.createElement("script");
        script.src = "animated_cards.js?v=20260427-3";
        script.defer = true;
        document.body.appendChild(script);
      }
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", inject);
    } else {
      inject();
    }
  }

  loadAnimatedCardsAssets();

  function isConfigured() {
    return !!(
      window.SUPABASE_CONFIG &&
      window.SUPABASE_CONFIG.url &&
      window.SUPABASE_CONFIG.anonKey &&
      !window.SUPABASE_CONFIG.url.includes("COLE_AQUI") &&
      !window.SUPABASE_CONFIG.anonKey.includes("COLE_AQUI")
    );
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

  function getAppPath(name, fallback) {
    return window.APP_CONFIG && window.APP_CONFIG.paths && window.APP_CONFIG.paths[name]
      ? window.APP_CONFIG.paths[name]
      : fallback;
  }

  function getRedirectUrl() {
    return new URL(getAppPath("login", "/login/"), window.location.origin).href;
  }

  function buildLoginRedirect(nextPath) {
    const loginPath = getAppPath("login", "/login/");
    return loginPath + "?next=" + encodeURIComponent(nextPath || getAppPath("home", "/"));
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

  async function requireAuth(nextPath) {
    if (!isConfigured()) {
      showConfigWarning();
      return null;
    }
    const session = await getSession();
    if (!session) {
      window.location.href = buildLoginRedirect(nextPath || window.location.pathname);
      return null;
    }
    return session.user;
  }

  async function isTeacherAdmin() {
    const client = getClient();
    const user = await getUser();
    if (!client || !user) return false;
    const response = await client.rpc("is_teacher_admin");
    if (response.error) {
      console.warn("Não foi possível verificar credenciais de professor:", response.error.message);
      return false;
    }
    return response.data === true;
  }

  async function requireTeacherAdmin(nextPath) {
    const user = await requireAuth(nextPath || window.location.pathname);
    if (!user) return null;

    const allowed = await isTeacherAdmin();
    if (!allowed) {
      window.location.href = getAppPath("home", "/");
      return null;
    }

    return user;
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
    if (cleanCpf.length !== 11) throw new Error("CPF inválido. Informe 11 dígitos.");
    if (cleanWhatsapp.length < 10) throw new Error("WhatsApp inválido.");
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

      const profileResponse = await client.from("profiles").upsert(profilePayload).select().single();
      if (profileResponse.error) {
        console.warn("Não foi possível atualizar profiles com os dados de matrícula:", profileResponse.error.message);
      }
    }

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
    window.location.href = getAppPath("login", "/login/");
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

  async function updateProfile(data) {
    const client = getClient();
    const user = await getUser();
    if (!client || !user) throw new Error("Usuário não autenticado.");

    const cleanCpf = normalizeCpf(data.cpf);
    const cleanWhatsapp = normalizeWhatsapp(data.whatsapp);
    const pixKey = normalizePixKey(data.pix_key);
    const availability = normalizeAvailability(data.availability);
    const availabilityColumns = availabilityToProfileColumns(availability);

    if (!data.name || !cleanCpf || !cleanWhatsapp || !pixKey) {
      throw new Error("Preencha nome, CPF, WhatsApp e chave PIX.");
    }
    if (cleanCpf.length !== 11) throw new Error("CPF inválido. Informe 11 dígitos.");
    if (cleanWhatsapp.length < 10) throw new Error("WhatsApp inválido.");
    if (countAvailabilitySlots(availability) === 0) {
      throw new Error("Selecione pelo menos um horário disponível para aulas durante a semana.");
    }

    const currentProfile = await getProfile();
    const profilePayload = Object.assign({
      id: user.id,
      name: data.name,
      email: user.email,
      cpf: cleanCpf,
      whatsapp: cleanWhatsapp,
      pix_key: pixKey,
      availability: availability,
      enrollment_code: currentProfile && currentProfile.enrollment_code || user.user_metadata && user.user_metadata.enrollment_code || "",
      enrolled: currentProfile && (currentProfile.enrolled === true || currentProfile.enrolled === "true") || user.user_metadata && (user.user_metadata.enrolled === true || user.user_metadata.enrolled === "true") || false
    }, availabilityColumns);

    const profileResponse = await client.from("profiles").upsert(profilePayload).select().single();
    if (profileResponse.error) throw profileResponse.error;

    const metadataResponse = await client.auth.updateUser({
      data: {
        name: data.name,
        cpf: cleanCpf,
        whatsapp: cleanWhatsapp,
        pix_key: pixKey,
        availability: availability,
        enrollment_code: profilePayload.enrollment_code,
        enrolled: profilePayload.enrolled
      }
    });
    if (metadataResponse.error) throw metadataResponse.error;

    return profileResponse.data;
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
    isConfigured: isConfigured,
    getClient: getClient,
    showConfigWarning: showConfigWarning,
    generateEnrollmentCode: generateEnrollmentCode,
    getSession: getSession,
    getUser: getUser,
    requireAuth: requireAuth,
    isTeacherAdmin: isTeacherAdmin,
    requireTeacherAdmin: requireTeacherAdmin,
    signUp: signUp,
    enrollStudent: enrollStudent,
    signIn: signIn,
    signOut: signOut,
    getProfile: getProfile,
    updateProfile: updateProfile,
    saveActivityResult: saveActivityResult,
    getMyResults: getMyResults
  };
})();
