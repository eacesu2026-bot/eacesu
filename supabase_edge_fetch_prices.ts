/**
 * ============================================================
 * Supabase Edge Function: fetch-stock-prices
 * ============================================================
 * المهمة: جلب أسعار الأسهم وتحديث جدول stock_prices عبر
 *         الدالة upsert_stock_price
 *
 * النشر:
 *   supabase functions deploy fetch-stock-prices
 *
 * الاستدعاء (يدوي أو من Cron):
 *   curl -X POST https://<PROJECT_REF>.supabase.co/functions/v1/fetch-stock-prices \
 *     -H "Authorization: Bearer <ANON_KEY>" \
 *     -H "x-cron-secret: <CRON_SECRET>" \
 *     -H "Content-Type: application/json"
 *
 * جدولة (Supabase Cron / pg_cron أو GitHub Actions كل دقيقة في جلسة التداول):
 *   SELECT cron.schedule('fetch-egx-prices', '0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58 8-15 * * 0-4', ...);
 *   (أي كل دقيقتين في ساعات الجلسة؛ لا تكتب الصيغة المختصرة بخط مائل داخل هذا التعليق لأنها تنهي التعليق)
 *
 * مهم جدًا:
 * - موقع EGX لا يوفّر API عام مجاني للاستخدام من التطبيقات.
 * - للاستخدام الإنتاجي يجب الاشتراك في مزود بيانات مرخّص
 *   (مثل Mubasher Pro, Refinitiv, Bloomberg, أو خدمة EGX الرسمية)
 *   ووضع المفتاح في Secrets:
 *     supabase secrets set MARKET_DATA_API_KEY=...
 *     supabase secrets set MARKET_DATA_BASE_URL=...
 * - هذا الملف يوضح الهيكل + مسارين:
 *   A) مزود مرخّص (موصى به)
 *   B) وضع تجريبي (dummy) للتطوير فقط
 * ============================================================
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MARKET_DATA_API_KEY = Deno.env.get("MARKET_DATA_API_KEY") ?? "";
const MARKET_DATA_BASE_URL = Deno.env.get("MARKET_DATA_BASE_URL") ?? "";
// سر مشترك لاستدعاء الدالة (cron/GitHub Actions): supabase secrets set CRON_SECRET=<قيمة عشوائية طويلة>
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
// الوضع التجريبي يكتب أسعارًا عشوائية في قاعدة البيانات — معطّل ما لم تفعّله صراحةً (للتطوير فقط)
const ALLOW_DEMO = Deno.env.get("ALLOW_DEMO") === "true";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface Quote {
  symbol: string;
  last: number;
  prev?: number;
  open?: number;
  high?: number;
  low?: number;
  volume?: number;
  value?: number;
  sourceTime?: string;
}

/** مسار A: استدعاء مزود بيانات مرخّص — عدّل المسار حسب وثائق المزود */
async function fetchFromLicensedProvider(symbols: string[]): Promise<Quote[]> {
  if (!MARKET_DATA_API_KEY || !MARKET_DATA_BASE_URL) {
    throw new Error("MARKET_DATA_API_KEY / MARKET_DATA_BASE_URL غير مضبوطين في Secrets");
  }

  // مثال عام — غيّره حسب API المزود الفعلي
  const url = `${MARKET_DATA_BASE_URL}/quotes?symbols=${symbols.join(",")}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${MARKET_DATA_API_KEY}`,
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Provider HTTP ${res.status}: ${text}`);
  }

  const data = await res.json();
  // عدّل التحويل حسب شكل استجابة المزود
  // متوقع: [{ symbol, last, prev, open, high, low, volume, value, time }]
  return (data.quotes ?? data ?? []).map((q: Record<string, unknown>) => ({
    symbol: String(q.symbol ?? q.Symbol ?? "").toUpperCase(),
    last: Number(q.last ?? q.Last ?? q.price ?? 0),
    prev: q.prev != null ? Number(q.prev) : undefined,
    open: q.open != null ? Number(q.open) : undefined,
    high: q.high != null ? Number(q.high) : undefined,
    low: q.low != null ? Number(q.low) : undefined,
    volume: q.volume != null ? Number(q.volume) : undefined,
    value: q.value != null ? Number(q.value) : undefined,
    sourceTime: (q.time as string) ?? new Date().toISOString(),
  }));
}

/** مسار B: تجريبي فقط — لا يُستخدم في الإنتاج */
async function fetchDemoQuotes(symbols: string[]): Promise<Quote[]> {
  // يحاكي تذبذبًا بسيطًا حول آخر سعر محفوظ
  const { data: rows } = await supabase.from("v_stock_quotes").select("symbol, last_price, prev_close");
  const map = new Map((rows ?? []).map((r) => [r.symbol, r]));

  return symbols.map((sym) => {
    const row = map.get(sym);
    const base = row?.last_price != null ? Number(row.last_price) : 100;
    const delta = (Math.random() - 0.5) * base * 0.004; // ±0.2%
    const last = Math.max(0.01, +(base + delta).toFixed(4));
    return {
      symbol: sym,
      last,
      prev: row?.prev_close != null ? Number(row.prev_close) : base,
      volume: Math.floor(Math.random() * 50000) + 1000,
      sourceTime: new Date().toISOString(),
    };
  });
}

Deno.serve(async (req) => {
  // مصادقة: لا يُنفَّذ الجلب إلا لمن يملك CRON_SECRET (مقارنة بزمن ثابت تقريبًا)
  const given = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || given.length !== CRON_SECRET.length ||
      [...given].reduce((a, c, i) => a | (c.charCodeAt(0) ^ CRON_SECRET.charCodeAt(i)), 0) !== 0) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json" },
    });
  }
  const started = Date.now();
  let status = "success";
  let message = "";
  let ok = 0;
  let fail = 0;

  try {
    // 1) قائمة الرموز النشطة من قاعدة البيانات
    const { data: stocks, error: stocksErr } = await supabase
      .from("stocks")
      .select("symbol")
      .eq("is_active", true);

    if (stocksErr) throw stocksErr;
    const symbols = (stocks ?? []).map((s) => s.symbol);
    if (!symbols.length) {
      return new Response(JSON.stringify({ ok: true, message: "لا توجد أسهم نشطة" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2) جلب الأسعار
    let quotes: Quote[];
    if (MARKET_DATA_API_KEY && MARKET_DATA_BASE_URL) {
      quotes = await fetchFromLicensedProvider(symbols);
      message = "fetched from licensed provider";
    } else {
      if (!ALLOW_DEMO) {
        throw new Error("MARKET_DATA_API_KEY / MARKET_DATA_BASE_URL غير مضبوطين، والوضع التجريبي معطّل (ALLOW_DEMO)");
      }
      quotes = await fetchDemoQuotes(symbols);
      message = "demo mode (no MARKET_DATA secrets) — لا تستخدم في الإنتاج";
      status = "partial";
    }

    // 3) تحديث القاعدة عبر RPC
    for (const q of quotes) {
      if (!q.symbol || !Number.isFinite(q.last) || q.last <= 0) {
        fail++;
        continue;
      }
      const { error } = await supabase.rpc("upsert_stock_price", {
        p_symbol: q.symbol,
        p_last_price: q.last,
        p_prev_close: q.prev ?? null,
        p_open: q.open ?? null,
        p_high: q.high ?? null,
        p_low: q.low ?? null,
        p_volume: q.volume ?? null,
        p_value: q.value ?? null,
        p_source: MARKET_DATA_API_KEY ? "provider" : "demo",
        p_source_time: q.sourceTime ?? new Date().toISOString(),
      });
      if (error) {
        fail++;
        console.error("upsert failed", q.symbol, error);
      } else {
        ok++;
      }
    }

    if (fail > 0 && ok === 0) status = "error";
    else if (fail > 0) status = "partial";

  } catch (e) {
    status = "error";
    message = e instanceof Error ? e.message : String(e);
    console.error(message);
  }

  const duration = Date.now() - started;

  await supabase.from("stock_fetch_logs").insert({
    provider: MARKET_DATA_API_KEY ? "licensed" : "demo",
    status,
    message,
    symbols_ok: ok,
    symbols_fail: fail,
    duration_ms: duration,
  });

  return new Response(
    JSON.stringify({ status, message, ok, fail, duration_ms: duration }),
    {
      status: status === "error" ? 500 : 200,
      headers: { "Content-Type": "application/json" },
    },
  );
});
