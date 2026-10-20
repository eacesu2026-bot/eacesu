-- ============================================================
-- EACESU — سكربت Supabase الموحّد الكامل
-- اتحاد العاملين المساهمين بشركة مصر للألومنيوم
-- نفّذه مرة واحدة في: Supabase → SQL Editor → Run
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ========== الملفات / الإعدادات العامة ==========
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.app_settings (key, value) VALUES
  ('branding', '{"union_name_ar":"اتحاد العاملين المساهمين بشركة مصر للألومنيوم","union_name_en":"Egypt Aluminum Company Employees'' Shareholders Union","primary_color":"#0b3d5c"}'::jsonb),
  ('finance', '{"union_shares":0,"avg_cost":0,"dividends":0}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ========== الأعضاء ==========
CREATE TABLE IF NOT EXISTS public.members (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name     TEXT NOT NULL,
  national_id   TEXT NOT NULL UNIQUE,
  phone         TEXT NOT NULL,
  emp_file_no   TEXT,
  shares_count  NUMERIC(18,4) NOT NULL DEFAULT 0,
  paid_amount   NUMERIC(18,2) NOT NULL DEFAULT 0,
  auth_user_id  UUID UNIQUE,  -- ربط auth.users عند التسجيل
  is_active     BOOLEAN NOT NULL DEFAULT true,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_members_phone ON public.members(phone);
CREATE INDEX IF NOT EXISTS idx_members_nid ON public.members(national_id);

-- ========== الهيكل التنظيمي ==========
CREATE TABLE IF NOT EXISTS public.org_positions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type        TEXT NOT NULL CHECK (type IN ('board','committee')),
  role_title  TEXT NOT NULL,
  person_name TEXT NOT NULL DEFAULT 'يُحدَّث لاحقًا',
  phone       TEXT,
  whatsapp    TEXT,
  photo_url   TEXT,
  initial     TEXT DEFAULT '؟',
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== الأخبار ==========
CREATE TABLE IF NOT EXISTS public.news (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type        TEXT NOT NULL DEFAULT 'news' CHECK (type IN ('news','decision','meeting','stocks')),
  title       TEXT NOT NULL,
  content     TEXT NOT NULL,
  source      TEXT DEFAULT 'مجلس الإدارة',
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== الشكاوى ==========
CREATE TABLE IF NOT EXISTS public.complaints (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   UUID REFERENCES public.members(id) ON DELETE SET NULL,
  full_name   TEXT NOT NULL,
  phone       TEXT,
  type        TEXT NOT NULL DEFAULT 'شكوى',
  message     TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'جديد' CHECK (status IN ('جديد','قيد المراجعة','مغلق')),
  admin_reply TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== الأسهم ==========
CREATE TABLE IF NOT EXISTS public.stocks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol        TEXT NOT NULL UNIQUE,
  isin          TEXT,
  name_ar       TEXT NOT NULL,
  name_en       TEXT,
  reuters_code  TEXT,
  currency      TEXT NOT NULL DEFAULT 'EGP',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  sort_order    INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_prices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_id        UUID NOT NULL REFERENCES public.stocks(id) ON DELETE CASCADE UNIQUE,
  last_price      NUMERIC(18,4) NOT NULL,
  prev_close      NUMERIC(18,4),
  open_price      NUMERIC(18,4),
  high_price      NUMERIC(18,4),
  low_price       NUMERIC(18,4),
  change_abs      NUMERIC(18,4),
  change_pct      NUMERIC(10,4),
  volume          BIGINT DEFAULT 0,
  value_traded    NUMERIC(20,2),
  source          TEXT NOT NULL DEFAULT 'manual',
  source_time     TIMESTAMPTZ,
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_price_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_id        UUID NOT NULL REFERENCES public.stocks(id) ON DELETE CASCADE,
  price           NUMERIC(18,4) NOT NULL,
  prev_close      NUMERIC(18,4),
  change_pct      NUMERIC(10,4),
  volume          BIGINT,
  source          TEXT NOT NULL DEFAULT 'manual',
  recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_price_hist ON public.stock_price_history(stock_id, recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.stock_fetch_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        TEXT NOT NULL,
  status          TEXT NOT NULL,
  message         TEXT,
  symbols_ok      INT DEFAULT 0,
  symbols_fail    INT DEFAULT 0,
  duration_ms     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== كشوف الحساب (حركات العضو) ==========
CREATE TABLE IF NOT EXISTS public.member_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id     UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  txn_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  txn_type      TEXT NOT NULL, -- استقطاع | توزيع | تسوية | شراء
  amount        NUMERIC(18,2) NOT NULL,
  shares_delta  NUMERIC(18,4) DEFAULT 0,
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_txn_member ON public.member_transactions(member_id, txn_date DESC);

-- ========== إحصائيات الدخول ==========
CREATE TABLE IF NOT EXISTS public.login_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   UUID REFERENCES public.members(id) ON DELETE SET NULL,
  role        TEXT NOT NULL DEFAULT 'member',
  ip_hash     TEXT,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== بيانات أولية ==========
INSERT INTO public.stocks (symbol, isin, name_ar, name_en, reuters_code, sort_order) VALUES
  ('EGAL', 'EGS3E181C010', 'مصر للألومنيوم', 'Egypt Aluminum', 'EGAL.CA', 1),
  ('COMI', 'EGS60121C018', 'البنك التجاري الدولي', 'CIB', 'COMI.CA', 2),
  ('HRHO', 'EGS69101C011', 'هيرميس القابضة', 'EFG Hermes', 'HRHO.CA', 3),
  ('TMGH', 'EGS65571C019', 'طلعت مصطفى', 'TMG Holding', 'TMGH.CA', 4)
ON CONFLICT (symbol) DO NOTHING;

INSERT INTO public.stock_prices (stock_id, last_price, prev_close, change_abs, change_pct, volume, source, source_time)
SELECT s.id, v.lp, v.pc, v.ca, v.cp, v.vol, 'manual', now()
FROM public.stocks s
JOIN (VALUES
  ('EGAL', 300.27, 298.50, 1.77, 0.59, 96256),
  ('COMI', 82.30, 81.90, 0.40, 0.49, 890000),
  ('HRHO', 15.70, 15.95, -0.25, -1.57, 340000),
  ('TMGH', 48.10, 47.50, 0.60, 1.26, 520000)
) AS v(sym, lp, pc, ca, cp, vol) ON s.symbol = v.sym
ON CONFLICT (stock_id) DO NOTHING;

INSERT INTO public.org_positions (type, role_title, person_name, initial, sort_order) VALUES
  ('board', 'رئيس مجلس الإدارة', 'يُحدَّث لاحقًا', 'ر', 1),
  ('board', 'نائب رئيس مجلس الإدارة', 'يُحدَّث لاحقًا', 'ن', 2),
  ('board', 'أمين الصندوق', 'يُحدَّث لاحقًا', 'أ', 3),
  ('board', 'سكرتير المجلس', 'يُحدَّث لاحقًا', 'س', 4),
  ('committee', 'لجنة الاستثمار', 'يُحدَّث لاحقًا', 'ل', 10),
  ('committee', 'لجنة الشؤون المالية', 'يُحدَّث لاحقًا', 'ل', 11),
  ('committee', 'لجنة العضوية والتواصل', 'يُحدَّث لاحقًا', 'ل', 12),
  ('committee', 'لجنة الشكاوى والمقترحات', 'يُحدَّث لاحقًا', 'ل', 13)
ON CONFLICT DO NOTHING;

-- ========== دالة تحديث السعر ==========
CREATE OR REPLACE FUNCTION public.upsert_stock_price(
  p_symbol TEXT, p_last_price NUMERIC,
  p_prev_close NUMERIC DEFAULT NULL, p_open NUMERIC DEFAULT NULL,
  p_high NUMERIC DEFAULT NULL, p_low NUMERIC DEFAULT NULL,
  p_volume BIGINT DEFAULT NULL, p_value NUMERIC DEFAULT NULL,
  p_source TEXT DEFAULT 'provider', p_source_time TIMESTAMPTZ DEFAULT now()
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_stock_id UUID; v_prev NUMERIC; v_change NUMERIC; v_pct NUMERIC; v_id UUID;
BEGIN
  SELECT id INTO v_stock_id FROM public.stocks WHERE symbol = upper(trim(p_symbol));
  IF v_stock_id IS NULL THEN RAISE EXCEPTION 'Symbol % not found', p_symbol; END IF;
  v_prev := COALESCE(p_prev_close, (SELECT last_price FROM public.stock_prices WHERE stock_id = v_stock_id));
  v_change := CASE WHEN v_prev IS NOT NULL THEN p_last_price - v_prev END;
  v_pct := CASE WHEN v_prev IS NOT NULL AND v_prev <> 0 THEN round(((p_last_price - v_prev)/v_prev)*100, 4) END;
  INSERT INTO public.stock_prices AS sp (
    stock_id, last_price, prev_close, open_price, high_price, low_price,
    change_abs, change_pct, volume, value_traded, source, source_time, fetched_at
  ) VALUES (
    v_stock_id, p_last_price, v_prev, p_open, p_high, p_low,
    v_change, v_pct, p_volume, p_value, p_source, p_source_time, now()
  )
  ON CONFLICT (stock_id) DO UPDATE SET
    last_price=EXCLUDED.last_price, prev_close=EXCLUDED.prev_close,
    open_price=EXCLUDED.open_price, high_price=EXCLUDED.high_price, low_price=EXCLUDED.low_price,
    change_abs=EXCLUDED.change_abs, change_pct=EXCLUDED.change_pct,
    volume=EXCLUDED.volume, value_traded=EXCLUDED.value_traded,
    source=EXCLUDED.source, source_time=EXCLUDED.source_time, fetched_at=now()
  RETURNING id INTO v_id;
  INSERT INTO public.stock_price_history (stock_id, price, prev_close, change_pct, volume, source, recorded_at)
  VALUES (v_stock_id, p_last_price, v_prev, v_pct, p_volume, p_source, COALESCE(p_source_time, now()));
  UPDATE public.stocks SET updated_at = now() WHERE id = v_stock_id;
  RETURN v_id;
END;
$$;

-- ========== View الأسعار ==========
DROP VIEW IF EXISTS public.v_stock_quotes;
CREATE VIEW public.v_stock_quotes AS
SELECT s.id, s.symbol, s.isin, s.name_ar, s.name_en, s.reuters_code, s.currency, s.sort_order,
  p.last_price, p.prev_close, p.change_abs, p.change_pct, p.volume, p.source, p.source_time, p.fetched_at
FROM public.stocks s
LEFT JOIN public.stock_prices p ON p.stock_id = s.id
WHERE s.is_active = true
ORDER BY s.sort_order;

-- ========== View إحصائيات ==========
DROP VIEW IF EXISTS public.v_dashboard_stats;
CREATE VIEW public.v_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM public.members WHERE is_active) AS members_count,
  COALESCE((SELECT (value->>'union_shares')::numeric FROM public.app_settings WHERE key='finance'), 0) AS union_shares,
  COALESCE((
    SELECT union_shares * COALESCE(p.last_price, 0)
    FROM (SELECT (value->>'union_shares')::numeric AS union_shares FROM public.app_settings WHERE key='finance') f
    LEFT JOIN public.stocks s ON s.symbol='EGAL'
    LEFT JOIN public.stock_prices p ON p.stock_id=s.id
  ), 0) AS market_value,
  (SELECT COUNT(*) FROM public.login_events) AS logins_count;

-- ========== RLS ==========
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_fetch_logs ENABLE ROW LEVEL SECURITY;

-- قراءة عامة للمحتوى العام
DROP POLICY IF EXISTS "public_read_org" ON public.org_positions;
CREATE POLICY "public_read_org" ON public.org_positions FOR SELECT USING (is_active);
DROP POLICY IF EXISTS "public_read_news" ON public.news;
CREATE POLICY "public_read_news" ON public.news FOR SELECT USING (is_published);
DROP POLICY IF EXISTS "public_read_stocks" ON public.stocks;
CREATE POLICY "public_read_stocks" ON public.stocks FOR SELECT USING (true);
DROP POLICY IF EXISTS "public_read_prices" ON public.stock_prices;
CREATE POLICY "public_read_prices" ON public.stock_prices FOR SELECT USING (true);
DROP POLICY IF EXISTS "public_read_history" ON public.stock_price_history;
CREATE POLICY "public_read_history" ON public.stock_price_history FOR SELECT USING (true);
DROP POLICY IF EXISTS "public_read_settings" ON public.app_settings;
CREATE POLICY "public_read_settings" ON public.app_settings FOR SELECT USING (true);

-- الشكاوى: أي شخص يُدرج، العضو يرى الخاصة به
DROP POLICY IF EXISTS "anyone_insert_complaint" ON public.complaints;
CREATE POLICY "anyone_insert_complaint" ON public.complaints FOR INSERT
  WITH CHECK (status = 'جديد' AND admin_reply IS NULL
              AND char_length(message) BETWEEN 1 AND 2000 AND char_length(full_name) BETWEEN 1 AND 200
              AND (member_id IS NULL OR member_id IN (SELECT id FROM public.members WHERE auth_user_id = auth.uid())));
DROP POLICY IF EXISTS "member_read_own_complaints" ON public.complaints;
CREATE POLICY "member_read_own_complaints" ON public.complaints FOR SELECT
  USING (auth.uid() IS NOT NULL AND member_id IN (SELECT id FROM public.members WHERE auth_user_id = auth.uid()));

-- العضو يرى بياناته وحركاته فقط
DROP POLICY IF EXISTS "member_read_self" ON public.members;
CREATE POLICY "member_read_self" ON public.members FOR SELECT
  USING (auth.uid() IS NOT NULL AND auth_user_id = auth.uid());
DROP POLICY IF EXISTS "member_read_own_txn" ON public.member_transactions;
CREATE POLICY "member_read_own_txn" ON public.member_transactions FOR SELECT
  USING (auth.uid() IS NOT NULL AND member_id IN (SELECT id FROM public.members WHERE auth_user_id = auth.uid()));

-- ===== صلاحيات الإدارة =====
-- الإدارة = مستخدم Supabase Auth تحمل بياناته app_metadata.role = 'admin'
-- (يُضبط من لوحة Supabase أو بـ service_role فقط؛ لا يستطيع المستخدم تعديله بنفسه).
-- ملاحظة: claim "role" في أعلى الـ JWT يساوي دائمًا authenticated/anon، لذلك نقرأ app_metadata.
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE AS $$ SELECT COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin' $$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['members','org_positions','news','complaints','stocks','stock_prices',
                           'stock_price_history','member_transactions','app_settings','login_events','stock_fetch_logs']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "admin_all_%1$s" ON public.%1$I', t);
    EXECUTE format('CREATE POLICY "admin_all_%1$s" ON public.%1$I FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin())', t);
  END LOOP;
END $$;

-- تحديث updated_at تلقائيًا
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['members','complaints','stocks','app_settings'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%1$s_updated ON public.%1$I', t);
    EXECUTE format('CREATE TRIGGER trg_%1$s_updated BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t);
  END LOOP;
END $$;

-- ===== إغلاق دالة تحديث الأسعار (SECURITY DEFINER) أمام الزوار =====
-- بدون هذا السطر كان أي زائر مجهول يستطيع استدعاءها عبر RPC وتغيير أسعار الأسهم.
REVOKE ALL ON FUNCTION public.upsert_stock_price(TEXT,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,BIGINT,NUMERIC,TEXT,TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_stock_price(TEXT,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,BIGINT,NUMERIC,TEXT,TIMESTAMPTZ) TO service_role;
-- الـ views تعمل بصلاحيات المالك؛ نجعلها تحترم RLS الخاص بالمستدعي
ALTER VIEW public.v_stock_quotes SET (security_invoker = true);
ALTER VIEW public.v_dashboard_stats SET (security_invoker = true);
-- app_settings تحتوي على بيانات مالية: القراءة العامة لمفتاح branding فقط
DROP POLICY IF EXISTS "public_read_settings" ON public.app_settings;
CREATE POLICY "public_read_settings" ON public.app_settings FOR SELECT USING (key = 'branding');
-- أرقام عامة آمنة للصفحة الرئيسية دون كشف جدول الأعضاء
CREATE OR REPLACE FUNCTION public.public_stats() RETURNS TABLE(members_count bigint, logins_count bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT (SELECT count(*) FROM members WHERE is_active), (SELECT count(*) FROM login_events) $$;
GRANT EXECUTE ON FUNCTION public.public_stats() TO anon, authenticated;

-- ========== Storage bucket للصور (يُنشأ من Dashboard أيضًا) ==========
-- في Storage أنشئ bucket باسم: media  (public read)
-- المسارات المقترحة: org/{id}.jpg | logos/header.png | docs/{file}

-- ===== خصوصية إضافية =====
-- 1) تحقق من الرقم القومي (14 رقمًا) — NOT VALID كي لا يفشل مع بيانات قديمة، ويُطبَّق على كل إدخال جديد
DO $$ BEGIN
  ALTER TABLE public.members ADD CONSTRAINT members_nid_14 CHECK (national_id ~ '^[0-9]{14}$') NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) سجل تدقيق: من غيّر/حذف بيانات الأعضاء أو الحركات المالية أو ردّ على شكوى (لا يخزّن الرقم القومي)
CREATE TABLE IF NOT EXISTS public.audit_log (
  id         BIGSERIAL PRIMARY KEY,
  at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor      UUID,
  table_name TEXT NOT NULL,
  action     TEXT NOT NULL,
  row_id     TEXT,
  changed    TEXT[]
);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_read_audit" ON public.audit_log;
CREATE POLICY "admin_read_audit" ON public.audit_log FOR SELECT USING (public.is_admin());
REVOKE INSERT, UPDATE, DELETE ON public.audit_log FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.audit_row() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb := to_jsonb(COALESCE(NEW, OLD)); o jsonb := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
        n jsonb := CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END; cols text[];
BEGIN
  SELECT array_agg(k) INTO cols FROM (SELECT key AS k FROM jsonb_each(n) EXCEPT SELECT key FROM jsonb_each(o) WHERE o->key = n->key) q;
  INSERT INTO public.audit_log(actor, table_name, action, row_id, changed)
  VALUES (auth.uid(), TG_TABLE_NAME, TG_OP, r->>'id', cols);
  RETURN COALESCE(NEW, OLD);
END $$;
REVOKE ALL ON FUNCTION public.audit_row() FROM PUBLIC, anon, authenticated;
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['members','member_transactions','complaints'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%1$s_audit ON public.%1$I', t);
    EXECUTE format('CREATE TRIGGER trg_%1$s_audit AFTER UPDATE OR DELETE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.audit_row()', t);
  END LOOP;
END $$;

SELECT 'EACESU schema installed successfully' AS status;
