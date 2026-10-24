-- ملاحظات صاحب النشاط + صلاحيات الإشعارات
CREATE TABLE IF NOT EXISTS owner_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user UUID,
  from_email TEXT,
  to_user_id UUID,
  to_label TEXT,
  body TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  read BOOLEAN DEFAULT false
);
ALTER TABLE owner_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth read notes" ON owner_notes;
DROP POLICY IF EXISTS "auth insert notes" ON owner_notes;
CREATE POLICY "auth read notes" ON owner_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth insert notes" ON owner_notes FOR INSERT TO authenticated WITH CHECK (true);

-- تأكد من أعمدة الإشعارات
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS kind text;
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS body text;
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS ref_type text;
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE IF EXISTS rep_notifications ADD COLUMN IF NOT EXISTS read boolean DEFAULT false;
