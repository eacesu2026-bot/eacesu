-- اختياري: عمود مسمى وظيفي (لا يغيّر الصلاحيات)
ALTER TABLE rep_profiles ADD COLUMN IF NOT EXISTS job_title TEXT;
UPDATE rep_profiles SET job_title = 'مشرف' WHERE name = 'فهد';
UPDATE rep_profiles SET job_title = 'مندوب' WHERE job_title IS NULL;
