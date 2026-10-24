/**
 * طبقة المزامنة السحابية مع Supabase
 * - تسجيل دخول بالبريد وكلمة المرور
 * - حفظ/تحميل بيانات الشركة
 * - تحديث فوري (Realtime) بين الأجهزة
 */
(function (global) {
  "use strict";

  const Cloud = {
    client: null,
    user: null,
    company: null,
    channel: null,
    ready: false,
    applyingRemote: false,

    configured() {
      const u = global.SUPABASE_URL || "";
      const k = global.SUPABASE_ANON_KEY || "";
      return !!(global.CLOUD_ENABLED && u && k && !u.includes("YOUR_PROJECT") && !k.includes("YOUR_ANON"));
    },

    init() {
      if (!this.configured()) {
        console.warn("[Cloud] غير مفعّل — العمل محليًا (localStorage)");
        return null;
      }
      if (!global.supabase || !global.supabase.createClient) {
        console.error("[Cloud] مكتبة supabase-js غير محمّلة");
        return null;
      }
      const url = String(global.SUPABASE_URL || "").replace(/^\uFEFF/, "").trim();
      const key = String(global.SUPABASE_ANON_KEY || "").replace(/^\uFEFF/, "").replace(/[\u200B-\u200D\uFEFF]/g, "").trim();
      // رفض مفاتيح تحتوي حروفًا غير ASCII (سبب خطأ headers)
      if ([...key].some(c => c.charCodeAt(0) > 255)) {
        console.error("[Cloud] ANON KEY يحتوي حروفًا غير لاتينية — أعد لصقه من Supabase");
        return null;
      }
      if (!url.startsWith("https://") || key.length < 20) {
        console.error("[Cloud] URL أو KEY غير صالح");
        return null;
      }
      this.client = global.supabase.createClient(url, key, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      });
      return this.client;
    },

    async getSession() {
      if (!this.client) this.init();
      if (!this.client) return null;
      const { data, error } = await this.client.auth.getSession();
      if (error) { console.error(error); return null; }
      this.user = data.session ? data.session.user : null;
      return data.session;
    },

    async login(email, password) {
      if (!this.client) this.init();
      const { data, error } = await this.client.auth.signInWithPassword({ email, password });
      if (error) throw error;
      this.user = data.user;
      return data;
    },

    async logout() {
      if (!this.client) return;
      await this.client.auth.signOut();
      this.user = null;
      if (this.channel) {
        try { this.client.removeChannel(this.channel); } catch (e) {}
        this.channel = null;
      }
    },

    async loadCompany(companyId) {
      if (!this.client) this.init();
      this.company = companyId;
      const { data, error } = await this.client
        .from("company_data")
        .select("data, updated_at")
        .eq("id", companyId)
        .maybeSingle();
      if (error) throw error;
      return data; // null if not exists
    },

    async saveCompany(companyId, dbObj) {
      if (!this.client) this.init();
      if (!this.client) throw new Error("السحابة غير مهيأة — تحقق من config.js");
      if (this.applyingRemote) return { skipped: true };
      if (!this.user) throw new Error("يجب تسجيل الدخول أولاً");
      const payload = {
        id: companyId,
        data: dbObj,
        updated_at: new Date().toISOString(),
        updated_by: this.user ? this.user.id : null
      };
      try {
        const { data, error } = await this.client
          .from("company_data")
          .upsert(payload, { onConflict: "id" })
          .select("updated_at")
          .single();
        if (error) {
          const msg = error.message || error.code || "خطأ غير معروف";
          if (String(msg).toLowerCase().includes("jwt") || error.code === "PGRST301")
            throw new Error("انتهت الجلسة — سجّل الدخول من جديد");
          if (String(msg).includes("payload") || String(msg).includes("size") || error.code === "54000")
            throw new Error("البيانات كبيرة جداً للرفع — احفظ محلياً");
          if (error.code === "42501" || String(msg).toLowerCase().includes("policy") || String(msg).toLowerCase().includes("rls"))
            throw new Error("صلاحيات RLS — راجع سياسات Supabase");
          throw new Error(msg);
        }
        return data;
      } catch (e) {
        if (e && e.message && !e.message.startsWith("السحابة") && !e.message.startsWith("يجب") && !e.message.startsWith("انتهت") && !e.message.startsWith("البيانات") && !e.message.startsWith("صلاحيات")) {
          // network etc.
          throw new Error("خطأ شبكة/سحابة: " + (e.message || String(e)));
        }
        throw e;
      }
    },

    async seedIfEmpty(companyId, seedObj) {
      const existing = await this.loadCompany(companyId);
      if (existing && existing.data) return existing.data;
      await this.saveCompany(companyId, seedObj);
      return seedObj;
    },

    subscribe(companyId, onChange) {
      if (!this.client) return;
      if (this.channel) {
        try { this.client.removeChannel(this.channel); } catch (e) {}
      }
      this.channel = this.client
        .channel("company-" + companyId)
        .on(
          "postgres_changes",
          { event: "*", schema: "public", table: "company_data", filter: "id=eq." + companyId },
          (payload) => {
            if (!payload.new || !payload.new.data) return;
            // تجاهل التحديثات الصادرة من نفس الجلسة إن أمكن
            onChange(payload.new.data, payload.new.updated_at);
          }
        )
        .subscribe((status) => {
          console.log("[Cloud] realtime:", status);
        });
    },


    /** مزامنة تلقائية: حفظ دوري + عند العودة للإنترنت + عند إظهار الصفحة */
    startAutoSync(companyId, getDb, opts) {
      opts = opts || {};
      const intervalMs = opts.intervalMs || 30000;
      const self = this;
      if (!companyId || typeof getDb !== "function") return;
      // منع تكرار المؤقت لنفس الشركة
      this._autoTimers = this._autoTimers || {};
      if (this._autoTimers[companyId]) {
        try { clearInterval(this._autoTimers[companyId]); } catch (e) {}
      }
      const push = async function (reason) {
        try {
          if (!self.configured() || !self.user || self.applyingRemote) return;
          if (typeof navigator !== "undefined" && navigator.onLine === false) return;
          const dbObj = getDb();
          if (!dbObj) return;
          await self.saveCompany(companyId, dbObj);
          if (opts.onOk) opts.onOk(reason || "auto");
        } catch (e) {
          if (opts.onErr) opts.onErr(e);
          else console.warn("[Cloud] auto-sync", companyId, e);
        }
      };
      this._autoTimers[companyId] = setInterval(function () { push("interval"); }, intervalMs);
      const onOnline = function () { push("online"); };
      const onVis = function () {
        if (typeof document !== "undefined" && !document.hidden) push("visible");
      };
      if (typeof window !== "undefined") {
        window.addEventListener("online", onOnline);
        document.addEventListener("visibilitychange", onVis);
      }
      // أول دفع بعد ثوانٍ
      setTimeout(function () { push("boot"); }, 5000);
      return function stop() {
        try { clearInterval(self._autoTimers[companyId]); } catch (e) {}
        try { window.removeEventListener("online", onOnline); } catch (e) {}
        try { document.removeEventListener("visibilitychange", onVis); } catch (e) {}
      };
    },

    /** مزامنة كل الشركات من localStorage إلى السحابة */
    async syncAllCompaniesFromLocal(companyIds) {
      const ids = companyIds || ["الراعي","الحموي","زدنا","فوليانا","بسكو مصر","ابويونس للتجارة والتوكيلات"];
      const results = [];
      for (const id of ids) {
        try {
          let dbObj = null;
          const keys = ["acc_abu_" + id + "_v2", "acc_abu_" + id];
          for (const k of keys) {
            try {
              const raw = localStorage.getItem(k);
              if (!raw) continue;
              const o = JSON.parse(raw);
              if (o && typeof o === "object") { dbObj = o; break; }
            } catch (e) {}
          }
          if (!dbObj) { results.push({ id, ok: false, msg: "لا بيانات محلية" }); continue; }
          await this.saveCompany(id, dbObj);
          results.push({ id, ok: true });
        } catch (e) {
          results.push({ id, ok: false, msg: (e && e.message) || String(e) });
        }
      }
      return results;
    },

    bindPageLifecycle(companyId, getDb) {
      const self = this;
      if (typeof window === "undefined") return;
      const saveNow = function () {
        try {
          if (!self.user || self.applyingRemote) return;
          const dbObj = typeof getDb === "function" ? getDb() : null;
          if (!dbObj) return;
          // keepalive-style: fire and forget
          self.saveCompany(companyId, dbObj).catch(function () {});
        } catch (e) {}
      };
      window.addEventListener("beforeunload", saveNow);
      window.addEventListener("pagehide", saveNow);
    },

    statusText() {
      if (!this.configured()) return "محلي";
      if (!this.user) return "غير مسجّل";
      return "سحابة ✓";
    }
  };

  global.AppCloud = Cloud;
})(window);
