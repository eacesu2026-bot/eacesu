/**
 * إعدادات Supabase — جاهز للتشغيل
 * افتح login.html في المتصفح وسجّل الدخول
 */
window.SUPABASE_URL = "https://gzzuwwbqqvcxotonfkoy.supabase.co";
window.SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6enV3d2JxcXZjeG90b25ma295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0MDM1NTAsImV4cCI6MjEwNTk3OTU1MH0.wTQ0dt8pkhTZX7ubHgSVpjHE6EcBafWo8ZTD9uFt-ZA";
window.CLOUD_ENABLED = true;

(function () {
  function clean(s) {
    if (typeof s !== "string") return "";
    return s.replace(/^\uFEFF/, "").replace(/[\u200B-\u200D\uFEFF]/g, "").trim();
  }
  window.SUPABASE_URL = clean(window.SUPABASE_URL);
  window.SUPABASE_ANON_KEY = clean(window.SUPABASE_ANON_KEY);
})();

/** إشعارات واتساب الفورية (اختياري)
 * الطريقة الموصى بها: CallMeBot (مجاني بعد تفعيل البوت مرة واحدة)
 * 1) أضف البوت على واتساب: https://www.callmebot.com/blog/free-api-whatsapp-messages/
 * 2) احصل على apikey بعد إرسال رسالة للبوت
 * 3) ضع رقم الإدارة الدولي بدون + مثل 2010xxxxxxxx
 */
window.ADMIN_WHATSAPP = window.ADMIN_WHATSAPP || "";      // مثال: "201012345678"
window.CALLMEBOT_APIKEY = window.CALLMEBOT_APIKEY || "";  // مفتاح CallMeBot
window.WHATSAPP_NOTIFY = true; // true لتفعيل محاولة الإرسال عند مسودة جديدة / اعتماد
