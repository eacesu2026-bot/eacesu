-- ============================================================
-- اتحاد العاملين المساهمين بشركة مصر للألومنيوم (EACESU)
-- Supabase SQL — جداول أسعار الأسهم + جاهزية الربط بالبورصة
-- انسخ هذا الملف بالكامل والصقه في: Supabase → SQL Editor → Run
-- ============================================================

-- ------------------------------------------------------------
-- 1) امتدادات مفيدة
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- 2) جدول الأسهم المراقبة (Watchlist)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stocks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol        TEXT NOT NULL UNIQUE,          -- مثال: EGAL
  isin          TEXT,                          -- مثال: EGS3E181C010
  name_ar       TEXT NOT NULL,                 -- مصر للألومنيوم
  name_en       TEXT,
  reuters_code  TEXT,                          -- EGAL.CA
  currency      TEXT NOT NULL DEFAULT 'EGP',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  sort_order    INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.stocks IS 'قائمة الأسهم التي يتابعها الاتحاد';

-- ------------------------------------------------------------
-- 3) آخر سعر معروف لكل سهم (يُحدَّث من Edge Function أو الإدارة)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_prices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_id        UUID NOT NULL REFERENCES public.stocks(id) ON DELETE CASCADE,
  last_price      NUMERIC(18,4) NOT NULL,
  prev_close      NUMERIC(18,4),
  open_price      NUMERIC(18,4),
  high_price      NUMERIC(18,4),
  low_price       NUMERIC(18,4),
  change_abs      NUMERIC(18,4),
  change_pct      NUMERIC(10,4),
  volume          BIGINT DEFAULT 0,
  value_traded    NUMERIC(20,2),
  source          TEXT NOT NULL DEFAULT 'manual',  -- manual | egx | provider_name
  source_time     TIMESTAMPTZ,                     -- وقت السعر من المصدر
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (stock_id)
);

COMMENT ON TABLE public.stock_prices IS 'آخر سعر لكل سهم — يُحدَّث دوريًا';

-- ------------------------------------------------------------
-- 4) سجل تاريخي للأسعار (للرسوم البيانية والتقارير)
-- ------------------------------------------------------------
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

CREATE INDEX IF NOT EXISTS idx_price_history_stock_time
  ON public.stock_price_history (stock_id, recorded_at DESC);

-- ------------------------------------------------------------
-- 5) سجل محاولات الجلب (للمراقبة والأخطاء)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_fetch_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        TEXT NOT NULL,               -- egx | mubasher | custom
  status          TEXT NOT NULL,               -- success | error | partial
  message         TEXT,
  symbols_ok      INT DEFAULT 0,
  symbols_fail    INT DEFAULT 0,
  duration_ms     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 6) بيانات أولية — سهم مصر للألومنيوم + أسهم متابعة شائعة
-- ------------------------------------------------------------
INSERT INTO public.stocks (symbol, isin, name_ar, name_en, reuters_code, sort_order)
VALUES
  ('EGAL', 'EGS3E181C010', 'مصر للألومنيوم', 'Egypt Aluminum', 'EGAL.CA', 1),
  ('COMI', 'EGS60121C018', 'البنك التجاري الدولي', 'Commercial International Bank', 'COMI.CA', 2),
  ('HRHO', 'EGS69101C011', 'هيرميس القابضة', 'EFG Hermes Holding', 'HRHO.CA', 3),
  ('TMGH', 'EGS65571C019', 'طلعت مصطفى القابضة', 'Talaat Moustafa Group', 'TMGH.CA', 4)
ON CONFLICT (symbol) DO NOTHING;

-- أسعار أولية تقريبية (تُستبدل عند أول جلب ناجح)
INSERT INTO public.stock_prices (stock_id, last_price, prev_close, change_abs, change_pct, volume, source, source_time)
SELECT s.id, v.last_price, v.prev_close, v.change_abs, v.change_pct, v.volume, 'manual', now()
FROM public.stocks s
JOIN (
  VALUES
    ('EGAL', 300.27, 298.50, 1.77, 0.59, 96256),
    ('COMI',  82.30,  81.90, 0.40, 0.49, 890000),
    ('HRHO',  15.70,  15.95,-0.25,-1.57, 340000),
    ('TMGH',  48.10,  47.50, 0.60, 1.26, 520000)
) AS v(symbol, last_price, prev_close, change_abs, change_pct, volume)
  ON s.symbol = v.symbol
ON CONFLICT (stock_id) DO NOTHING;

-- ------------------------------------------------------------
-- 7) دالة مساعدة: upsert سعر سهم بالرمز
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_stock_price(
  p_symbol      TEXT,
  p_last_price  NUMERIC,
  p_prev_close  NUMERIC DEFAULT NULL,
  p_open        NUMERIC DEFAULT NULL,
  p_high        NUMERIC DEFAULT NULL,
  p_low         NUMERIC DEFAULT NULL,
  p_volume      BIGINT DEFAULT NULL,
  p_value       NUMERIC DEFAULT NULL,
  p_source      TEXT DEFAULT 'provider',
  p_source_time TIMESTAMPTZ DEFAULT now()
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock_id UUID;
  v_prev     NUMERIC;
  v_change   NUMERIC;
  v_pct      NUMERIC;
  v_price_id UUID;
BEGIN
  SELECT id INTO v_stock_id FROM public.stocks WHERE symbol = upper(trim(p_symbol));
  IF v_stock_id IS NULL THEN
    RAISE EXCEPTION 'Symbol % not found in stocks watchlist', p_symbol;
  END IF;

  v_prev := COALESCE(p_prev_close, (
    SELECT last_price FROM public.stock_prices WHERE stock_id = v_stock_id
  ));
  v_change := CASE WHEN v_prev IS NOT NULL THEN p_last_price - v_prev ELSE NULL END;
  v_pct := CASE WHEN v_prev IS NOT NULL AND v_prev <> 0
                THEN round(((p_last_price - v_prev) / v_prev) * 100, 4)
                ELSE NULL END;

  INSERT INTO public.stock_prices AS sp (
    stock_id, last_price, prev_close, open_price, high_price, low_price,
    change_abs, change_pct, volume, value_traded, source, source_time, fetched_at
  ) VALUES (
    v_stock_id, p_last_price, v_prev, p_open, p_high, p_low,
    v_change, v_pct, p_volume, p_value, p_source, p_source_time, now()
  )
  ON CONFLICT (stock_id) DO UPDATE SET
    last_price   = EXCLUDED.last_price,
    prev_close   = EXCLUDED.prev_close,
    open_price   = EXCLUDED.open_price,
    high_price   = EXCLUDED.high_price,
    low_price    = EXCLUDED.low_price,
    change_abs   = EXCLUDED.change_abs,
    change_pct   = EXCLUDED.change_pct,
    volume       = EXCLUDED.volume,
    value_traded = EXCLUDED.value_traded,
    source       = EXCLUDED.source,
    source_time  = EXCLUDED.source_time,
    fetched_at   = now()
  RETURNING id INTO v_price_id;

  -- حفظ نقطة في التاريخ
  INSERT INTO public.stock_price_history (stock_id, price, prev_close, change_pct, volume, source, recorded_at)
  VALUES (v_stock_id, p_last_price, v_prev, v_pct, p_volume, p_source, COALESCE(p_source_time, now()));

  UPDATE public.stocks SET updated_at = now() WHERE id = v_stock_id;

  RETURN v_price_id;
END;
$$;

COMMENT ON FUNCTION public.upsert_stock_price IS
  'تُستدعى من Edge Function بعد جلب السعر من مزود البيانات';

-- ------------------------------------------------------------
-- 8) View جاهز للواجهة (آخر الأسعار + بيانات السهم)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_stock_quotes AS
SELECT
  s.id,
  s.symbol,
  s.isin,
  s.name_ar,
  s.name_en,
  s.reuters_code,
  s.currency,
  s.is_active,
  s.sort_order,
  p.last_price,
  p.prev_close,
  p.open_price,
  p.high_price,
  p.low_price,
  p.change_abs,
  p.change_pct,
  p.volume,
  p.value_traded,
  p.source,
  p.source_time,
  p.fetched_at
FROM public.stocks s
LEFT JOIN public.stock_prices p ON p.stock_id = s.id
WHERE s.is_active = true
ORDER BY s.sort_order, s.symbol;

-- ------------------------------------------------------------
-- 9) Row Level Security
-- ------------------------------------------------------------
ALTER TABLE public.stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_fetch_logs ENABLE ROW LEVEL SECURITY;

-- قراءة عامة للأسعار (الأعضاء والزوار)
DROP POLICY IF EXISTS "stocks_public_read" ON public.stocks;
CREATE POLICY "stocks_public_read" ON public.stocks
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "prices_public_read" ON public.stock_prices;
CREATE POLICY "prices_public_read" ON public.stock_prices
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "history_public_read" ON public.stock_price_history;
CREATE POLICY "history_public_read" ON public.stock_price_history
  FOR SELECT USING (true);

-- الكتابة للإدارة فقط (عبر service_role من Edge Function أو مستخدم admin)
-- ملاحظة: Edge Functions تستخدم service_role وتتجاوز RLS افتراضيًا

DROP POLICY IF EXISTS "stocks_admin_all" ON public.stocks;
CREATE POLICY "stocks_admin_all" ON public.stocks
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

DROP POLICY IF EXISTS "prices_admin_all" ON public.stock_prices;
CREATE POLICY "prices_admin_all" ON public.stock_prices
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- السماح لـ authenticated بقراءة السجلات إن رغبت
DROP POLICY IF EXISTS "logs_admin_read" ON public.stock_fetch_logs;
CREATE POLICY "logs_admin_read" ON public.stock_fetch_logs
  FOR SELECT
  USING (auth.jwt() ->> 'role' = 'admin');

-- ------------------------------------------------------------
-- 10) تحديث updated_at تلقائيًا
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stocks_updated ON public.stocks;
CREATE TRIGGER trg_stocks_updated
  BEFORE UPDATE ON public.stocks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- انتهى السكربت الأساسي
-- بعد التشغيل: أنشئ Edge Function لجلب الأسعار (انظر الملف المرفق التالي)
-- ============================================================
