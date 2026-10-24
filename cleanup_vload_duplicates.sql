-- تنظيف طلبات تحميل السيارة المكررة (يُبقي أحدث سجل لكل مندوب+صنف+يوم)
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY rep_id, COALESCE(item_id, item_name), load_date, COALESCE(company,'')
           ORDER BY created_at DESC NULLS LAST
         ) AS rn
  FROM rep_vehicle_load_draft
  WHERE status = 'pending'
)
DELETE FROM rep_vehicle_load_draft
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
