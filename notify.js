/**
 * إشعارات: داخل المتصفح + واتساب (CallMeBot اختياري)
 */
window.AYNotify = {
  async browser(title, body) {
    try {
      if (!("Notification" in window)) return;
      if (Notification.permission === "default") await Notification.requestPermission();
      if (Notification.permission === "granted") {
        new Notification(title, { body: body || "", icon: "logo-abu-younes.jpg" });
      }
    } catch (e) {}
  },
  async whatsapp(text) {
    if (window.WHATSAPP_NOTIFY === false) return { ok: false, reason: "disabled" };
    const phone = String(window.ADMIN_WHATSAPP || "").replace(/\D/g, "");
    const key = String(window.CALLMEBOT_APIKEY || "").trim();
    if (!phone || !key) return { ok: false, reason: "missing_config" };
    try {
      // CallMeBot — لا يحتاج CORS عبر صورة/beacon أحيانًا؛ نستخدم fetch no-cors كمحاولة
      const url = "https://api.callmebot.com/whatsapp.php?phone=" + encodeURIComponent(phone)
        + "&text=" + encodeURIComponent(text)
        + "&apikey=" + encodeURIComponent(key);
      await fetch(url, { mode: "no-cors" });
      return { ok: true };
    } catch (e) {
      return { ok: false, reason: String(e) };
    }
  },
  async both(title, body) {
    await this.browser(title, body);
    await this.whatsapp("*" + title + "*\n" + (body || ""));
  }
};
