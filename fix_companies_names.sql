-- إصلاح أسماء الشركات في rep_profiles إن كانت "شركة 1" إلخ
UPDATE rep_profiles
SET companies = ARRAY(
  SELECT DISTINCT CASE
    WHEN c IN ('شركة 1','شركة1','1','company1') OR c LIKE '%الراعي%' THEN 'الراعي'
    WHEN c IN ('شركة 2','شركة2','2','company2') OR c LIKE '%الحموي%' THEN 'الحموي'
    WHEN c IN ('شركة 3','شركة3','3','company3') OR c LIKE '%زدنا%' THEN 'زدنا'
    WHEN c IN ('شركة 4','شركة4','4','company4') OR c LIKE '%فوليانا%' THEN 'فوليانا'
    ELSE c
  END
  FROM unnest(companies) AS c
)
WHERE companies IS NOT NULL;

-- تعيين الأربع شركات لكل من لا يملك شركات
UPDATE rep_profiles
SET companies = ARRAY['الراعي','الحموي','زدنا','فوليانا','بسكو مصر']
WHERE companies IS NULL OR companies = '{}';

SELECT name, companies, job_title FROM rep_profiles;
