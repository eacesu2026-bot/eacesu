-- ============================================================
-- ربط حسابات المندوبين بعد إنشائهم من Authentication
-- نفّذ هذا في SQL Editor بعد إضافة المستخدمين الأربعة من Auth
-- لا حاجة لنسخ UUID يدوياً — الربط بالبريد تلقائي
-- ============================================================

ALTER TABLE rep_profiles ADD COLUMN IF NOT EXISTS job_title TEXT DEFAULT 'مندوب';

-- فهد · مشرف
INSERT INTO rep_profiles (user_id, name, username, companies, phone, active, job_title)
SELECT id, 'فهد', email, ARRAY['الراعي','الحموي','زدنا','فوليانا','بسكو مصر'], '', true, 'مشرف'
FROM auth.users WHERE lower(email) = lower('rep1@abuyounes.com')
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  username = EXCLUDED.username,
  companies = EXCLUDED.companies,
  job_title = EXCLUDED.job_title,
  active = true;

-- مصطفى · مندوب
INSERT INTO rep_profiles (user_id, name, username, companies, phone, active, job_title)
SELECT id, 'مصطفى', email, ARRAY['الراعي','الحموي','زدنا','فوليانا','بسكو مصر'], '', true, 'مندوب'
FROM auth.users WHERE lower(email) = lower('rep2@abuyounes.com')
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  username = EXCLUDED.username,
  companies = EXCLUDED.companies,
  job_title = EXCLUDED.job_title,
  active = true;

-- محمد · مندوب
INSERT INTO rep_profiles (user_id, name, username, companies, phone, active, job_title)
SELECT id, 'محمد', email, ARRAY['الراعي','الحموي','زدنا','فوليانا','بسكو مصر'], '', true, 'مندوب'
FROM auth.users WHERE lower(email) = lower('rep3@abuyounes.com')
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  username = EXCLUDED.username,
  companies = EXCLUDED.companies,
  job_title = EXCLUDED.job_title,
  active = true;

-- علي · مندوب (rep4 — ليس rep3)
INSERT INTO rep_profiles (user_id, name, username, companies, phone, active, job_title)
SELECT id, 'علي', email, ARRAY['الراعي','الحموي','زدنا','فوليانا','بسكو مصر'], '', true, 'مندوب'
FROM auth.users WHERE lower(email) = lower('rep4@abuyounes.com')
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  username = EXCLUDED.username,
  companies = EXCLUDED.companies,
  job_title = EXCLUDED.job_title,
  active = true;

-- تحقق: يجب أن ترى 4 صفوف
SELECT name, username, job_title, companies, active
FROM rep_profiles
WHERE username IN (
  'rep1@abuyounes.com','rep2@abuyounes.com','rep3@abuyounes.com','rep4@abuyounes.com'
)
ORDER BY username;
