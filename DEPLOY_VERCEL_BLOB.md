# ربط Vercel Blob — التخزين السحابي لملفات الاتحاد

## ما أُضيف في المشروع

| الملف / المكان | الدور |
|----------------|--------|
| `api/upload.js` | يعطي صلاحية الرفع (`handleUploadUrl: '/api/upload'`) |
| `package.json` | يعتمد `@vercel/blob` |
| `vercel.json` | إعدادات النشر |
| `.gitignore` | تجاهل `.env` و `node_modules` |
| `index.html` | رفع اللوائح وصور المناصب عبر السحابة مع احتياطي محلي |

---

## الأوامر بالترتيب (نفّذها على جهازك)

من مجلد المشروع بعد نسخ الملفات:

```bash
# 1) تثبيت أداة Vercel عالميًا
npm install -g vercel

# 2) تسجيل الدخول لحساب Vercel
vercel login

# 3) ربط المجلد بالمشروع على Vercel
vercel link

# 4) سحب متغيرات البيئة (بعد إنشاء Blob من اللوحة)
vercel env pull .env.local

# 5) تثبيت مكتبة التخزين
npm install @vercel/blob

# 6) رفع التعديلات إلى GitHub
git add .
git commit -m "تم إضافة سحابة التخزين بنجاح"
git push origin main
```

بعد `git push`، Vercel يعيد النشر تلقائيًا إن كان المشروع مربوطًا بالمستودع.

---

## إعداد التوكن (مرة واحدة من لوحة Vercel)

1. Vercel → Project → **Storage** → **Blob** → Create  
2. اربط المتجر بالمشروع  
3. سيُضاف تلقائيًا: `BLOB_READ_WRITE_TOKEN`
3b. **أضف `ADMIN_UPLOAD_KEY`** (نص عشوائي طويل) — مطلوب وإلا يرفض الخادم أي رفع. تطلبه الواجهة من الإدارة عند أول رفع.  
4. أو: Settings → Environment Variables → أضف `BLOB_READ_WRITE_TOKEN`  
5. أعد النشر: `vercel --prod` أو Push جديد

---

## كود الرفع في الواجهة (مُدمج مسبقًا)

```js
import { upload } from '@vercel/blob/client';
// يُحمَّل ديناميكيًا من الصفحة عند الرفع:
const newBlob = await upload(file.name, file, {
  access: 'public',
  handleUploadUrl: '/api/upload',
});
// newBlob.url = رابط الملف السحابي
```

يُستخدم عند:
- رفع **لوائح الشركة**
- رفع **صور المناصب** في الهيكل التنظيمي

إن لم يكن التوكن/المفتاح جاهزًا، يُحفظ الملف مؤقتًا محليًا (Base64) حتى تفعيل السحابة.

---

## هيكل الملفات النهائي للرفع على GitHub

```
/
├── index.html
├── sw.js
├── manifest.json
├── header-logos.png
├── icon-192.png
├── icon-512.png
├── lib/ (html2pdf + blob-client — محلية)
├── package.json
├── vercel.json
├── .gitignore
└── api/
    └── upload.js
```

لا ترفع: `node_modules/` ولا `.env.local`
