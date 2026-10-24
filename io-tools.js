/**
 * أدوات موحّدة: حفظ PDF · تصدير · استيراد
 * يُحمَّل في كل أنظمة أبو يونس
 */
(function (global) {
  "use strict";

  function downloadBlob(blob, filename) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(function () {
      URL.revokeObjectURL(a.href);
      a.remove();
    }, 500);
  }

  function downloadText(text, filename, mime) {
    downloadBlob(new Blob([text], { type: mime || "text/plain;charset=utf-8" }), filename);
  }

  function stamp() {
    const d = new Date();
    const p = function (n) { return String(n).padStart(2, "0"); };
    return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "_" + p(d.getHours()) + p(d.getMinutes());
  }

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector('script[src="' + src + '"]')) return resolve();
      const s = document.createElement("script");
      s.src = src;
      s.onload = resolve;
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  const IO = {
    /** تصدير كائن JSON */
    exportJSON: function (data, name) {
      const fn = (name || "abu_younes") + "_" + stamp() + ".json";
      downloadText(JSON.stringify(data, null, 2), fn, "application/json;charset=utf-8");
      return fn;
    },

    /** استيراد JSON عبر اختيار ملف */
    importJSON: function (cb) {
      const inp = document.createElement("input");
      inp.type = "file";
      inp.accept = ".json,application/json";
      inp.onchange = function () {
        const f = inp.files && inp.files[0];
        if (!f) return;
        const r = new FileReader();
        r.onload = function () {
          try {
            const obj = JSON.parse(r.result);
            if (typeof cb === "function") cb(null, obj, f.name);
          } catch (e) {
            if (typeof cb === "function") cb(e);
            else alert("ملف JSON غير صالح");
          }
        };
        r.onerror = function () {
          if (typeof cb === "function") cb(new Error("تعذر القراءة"));
        };
        r.readAsText(f);
      };
      inp.click();
    },

    /** تصدير جدول HTML أو مصفوفة كـ CSV */
    exportCSV: function (rowsOrTable, name) {
      let rows = [];
      if (typeof rowsOrTable === "string") {
        const tb = document.querySelector(rowsOrTable);
        if (tb) {
          tb.querySelectorAll("tr").forEach(function (tr) {
            const cells = [];
            tr.querySelectorAll("th,td").forEach(function (td) {
              cells.push('"' + String(td.innerText || "").replace(/"/g, '""').replace(/\n/g, " ") + '"');
            });
            if (cells.length) rows.push(cells.join(","));
          });
        }
      } else if (Array.isArray(rowsOrTable)) {
        rows = rowsOrTable.map(function (r) {
          return (Array.isArray(r) ? r : [r])
            .map(function (c) { return '"' + String(c == null ? "" : c).replace(/"/g, '""') + '"'; })
            .join(",");
        });
      }
      const bom = "\uFEFF";
      downloadText(bom + rows.join("\n"), (name || "export") + "_" + stamp() + ".csv", "text/csv;charset=utf-8");
    },

    /** حفظ PDF للعنصر المرئي (html2pdf) أو طباعة احتياطية */
    savePDF: async function (elOrSelector, filename) {
      let el = elOrSelector;
      if (typeof el === "string") el = document.querySelector(el);
      if (!el) {
        // الصفحة الحالية
        el = document.querySelector(".main") || document.querySelector("#appView") || document.body;
      }
      const fn = (filename || "تقرير") + "_" + stamp() + ".pdf";
      try {
        await loadScript("https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js");
        if (!global.html2pdf) throw new Error("html2pdf missing");
        const opt = {
          margin: [8, 8, 8, 8],
          filename: fn,
          image: { type: "jpeg", quality: 0.95 },
          html2canvas: { scale: 2, useCORS: true, scrollY: 0 },
          jsPDF: { unit: "mm", format: "a4", orientation: "portrait" },
          pagebreak: { mode: ["avoid-all", "css", "legacy"] }
        };
        await global.html2pdf().set(opt).from(el).save();
        return fn;
      } catch (e) {
        console.warn("html2pdf fallback print", e);
        // احتياطي: نافذة طباعة (المستخدم يختار حفظ PDF)
        const w = window.open("", "_blank");
        if (!w) {
          alert("اسمح بالنوافذ المنبثقة أو استخدم Ctrl+P واختر حفظ كـ PDF");
          window.print();
          return null;
        }
        w.document.write("<!DOCTYPE html><html dir=rtl lang=ar><head><meta charset=UTF-8><title>" + fn +
          "</title><style>body{font-family:Tahoma,Arial;padding:16px;color:#000}table{width:100%;border-collapse:collapse;font-size:12px}" +
          "th,td{border:1px solid #ccc;padding:4px 6px;text-align:right}th{background:#eee}" +
          "@media print{body{padding:0}}</style></head><body>" + el.innerHTML + "</body></html>");
        w.document.close();
        setTimeout(function () { w.focus(); w.print(); }, 400);
        return null;
      }
    },

    /** شريط أزرار سريع يُحقن في الصفحة */
    injectToolbar: function (opts) {
      opts = opts || {};
      if (document.getElementById("ayIoBar")) return;
      const bar = document.createElement("div");
      bar.id = "ayIoBar";
      bar.className = "no-print";
      bar.style.cssText = "display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:6px 0;padding:6px 8px;" +
        "background:rgba(30,58,95,.08);border:1px solid #cbd5e1;border-radius:10px;font-size:.78rem";
      bar.innerHTML =
        '<span style="font-weight:700;color:#1e3a5f;margin-left:4px">ملفات</span>' +
        '<button type="button" id="ayIoPdf" style="padding:6px 10px;border-radius:8px;border:0;background:#b91c1c;color:#fff;cursor:pointer;font-weight:600">PDF</button>' +
        '<button type="button" id="ayIoExport" style="padding:6px 10px;border-radius:8px;border:0;background:#1d4ed8;color:#fff;cursor:pointer;font-weight:600">تصدير</button>' +
        '<button type="button" id="ayIoImport" style="padding:6px 10px;border-radius:8px;border:0;background:#15803d;color:#fff;cursor:pointer;font-weight:600">استيراد</button>' +
        '<button type="button" id="ayIoCsv" style="padding:6px 10px;border-radius:8px;border:1px solid #94a3b8;background:#fff;color:#0f172a;cursor:pointer;font-weight:600">CSV</button>' +
        '<span id="ayIoMsg" style="font-size:.72rem;color:#475569"></span>';
      const host = opts.host
        || document.querySelector(".bar")
        || document.querySelector(".top")
        || document.querySelector("h1")
        || document.body.firstElementChild;
      if (host && host.parentNode) {
        if (host.tagName === "H1") host.parentNode.insertBefore(bar, host.nextSibling);
        else host.appendChild(bar);
      } else document.body.insertBefore(bar, document.body.firstChild);

      const msg = function (t) {
        const m = document.getElementById("ayIoMsg");
        if (m) m.textContent = t || "";
      };

      document.getElementById("ayIoPdf").onclick = async function () {
        msg("جاري إعداد PDF...");
        const target = opts.pdfTarget
          || document.querySelector(".main")
          || document.querySelector("#appView")
          || document.querySelector(".card")
          || document.body;
        try {
          await IO.savePDF(target, opts.pdfName || document.title || "تقرير");
          msg("تم PDF");
        } catch (e) {
          msg("تعذر PDF");
        }
      };

      document.getElementById("ayIoExport").onclick = function () {
        let data = null;
        if (typeof opts.getData === "function") data = opts.getData();
        else if (typeof global.db !== "undefined") data = global.db;
        else if (global.AppCloud && global.COMPANY) data = { company: global.COMPANY, note: "لا بيانات محلية" };
        else data = { exportedAt: new Date().toISOString(), title: document.title };
        const fn = IO.exportJSON(data, opts.fileName || (global.COMPANY || "abu_younes"));
        msg("تصدير: " + fn);
      };

      document.getElementById("ayIoImport").onclick = function () {
        if (typeof opts.onImport !== "function" && typeof global.db === "undefined") {
          alert("الاستيراد غير متاح في هذه الشاشة");
          return;
        }
        IO.importJSON(function (err, obj) {
          if (err) { alert("فشل الاستيراد: " + (err.message || err)); return; }
          if (typeof opts.onImport === "function") {
            opts.onImport(obj);
            msg("تم الاستيراد");
            return;
          }
          if (!confirm("استبدال بيانات الشركة الحالية بالملف المستورد؟")) return;
          try {
            global.db = obj;
            if (typeof global.save === "function") global.save();
            if (typeof global.renderAll === "function") global.renderAll();
            msg("تم الاستيراد ✓");
          } catch (e) {
            alert(e.message || e);
          }
        });
      };

      document.getElementById("ayIoCsv").onclick = function () {
        const table = opts.csvTable
          || document.querySelector(".tab-pane:not(.hidden) table")
          || document.querySelector(".pane.on table")
          || document.querySelector("table");
        if (!table) { alert("لا يوجد جدول ظاهر"); return; }
        IO.exportCSV(table, opts.fileName || "table");
        msg("تم CSV");
      };
    }
  };

  global.AY_IO = IO;

  // حقن تلقائي خفيف بعد التحميل
  function auto() {
    try {
      if (document.body && !document.getElementById("ayIoBar")) {
        // لا تحقن في صفحات الدخول فقط
        if (/login\.html$/i.test(location.pathname)) return;
        IO.injectToolbar({});
      }
    } catch (e) {}
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { setTimeout(auto, 600); });
  else setTimeout(auto, 600);
})(typeof window !== "undefined" ? window : this);
