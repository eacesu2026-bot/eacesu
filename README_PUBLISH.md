# EACESU — دليل التنفيذ على GitHub + Vercel

## حساب الإدارة
- الإيميل: eacesu2026@gmail.com
- كلمة المرور: Prof@015
- صلاحيات كاملة: إضافة/تعديل/حذف/تصدير/استيراد/طباعة/PDF/تصويت إداري (اطلاع وطباعة فقط)

## الملفات على المستودع (جذر المشروع)
```
/
├── index.html
├── sw.js
├── manifest.json
└── header-logos.png
```

## النشر على GitHub ثم Vercel

### 1) GitHub
1. أنشئ مستودعًا جديدًا (مثلاً eacesu-web) — Public أو Private.
2. ارفع الملفات الأربعة في الجذر (ليس داخل مجلد فرعي إن أمكن).
3. Commit + Push.

من الطرفية:
```bash
git init
git add index.html sw.js manifest.json header-logos.png
git commit -m "EACESU platform"
git branch -M main
git remote add origin https://github.com/USER/REPO.git
git push -u origin main
```

### 2) Vercel
1. ادخل vercel.com وسجّل بحساب GitHub.
2. Add New Project → استورد المستودع.
3. Framework Preset: Other (أو static).
4. Root Directory: . (الجذر)
5. Build Command: اتركه فارغًا
6. Output Directory: . (أو اترك الافتراضي)
7. Deploy.

بعد النشر ستحصل على: https://xxx.vercel.app

### 3) نطاق مخصص (اختياري)
Vercel → Project → Settings → Domains → أضف نطاق الاتحاد واتبع DNS.

## أكواد Supabase (ليست على Vercel)
| الملف | المكان |
|--------|--------|
| supabase_full_schema.sql | Supabase → SQL Editor → Run |
| supabase_edge_fetch_prices.ts | Supabase → Edge Functions → Deploy |

## ميزات الإدارة بعد التحديث
- تصدير JSON / استيراد JSON
- طباعة الصفحة
- حفظ PDF
- حفظ وتحديث الأعضاء مع ظهور فوري في القائمة
- إصلاح تسجيل الدخول والتسجيل (كان معطلاً بسبب خطأ برمجي)

## ملاحظات
- يجب HTTPS (Vercel يوفره تلقائيًا) لتثبيت PWA.
- البيانات تُحفظ في متصفح الإدارة (localStorage) حتى ربط Supabase.
