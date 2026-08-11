import { Router } from 'express';

const router = Router();

/** Free rate sources (no API key). Tried in parallel — first good response wins. */
const SOURCES = [
  (base) => `https://open.er-api.com/v6/latest/${encodeURIComponent(base)}`,
  (base) => `https://api.frankfurter.app/latest?from=${encodeURIComponent(base)}`,
  (base) => `https://api.frankfurter.dev/v1/latest?base=${encodeURIComponent(base)}`,
];

/** In-memory cache so dashboard / converter do not re-hit upstream every page load */
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const cache = new Map(); // base -> { at, payload }

const UPSTREAM_TIMEOUT_MS = 4500;

/** Normalize upstream dates to `YYYY-MM-DD` (never sliced HTTP strings like "Sat, 08 Au"). */
function normalizeFxDate(data) {
  const isoLike = (v) => {
    if (v == null) return null;
    const s = String(v).trim();
    // Already ISO calendar date
    if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
    const d = new Date(s);
    if (!Number.isNaN(d.getTime())) return d.toISOString().slice(0, 10);
    return null;
  };

  return (
    isoLike(data.date) ||
    isoLike(data.time_last_update_utc) ||
    isoLike(data.time_last_update) ||
    new Date().toISOString().slice(0, 10)
  );
}

function parseRatesPayload(data, fallbackBase) {
  const rates = data.rates || {};
  const from = (data.base || data.base_code || fallbackBase).toUpperCase();
  const date = normalizeFxDate(data);

  if (!rates || typeof rates !== 'object' || !Object.keys(rates).length) {
    return null;
  }
  return { base: from, date, rates };
}

async function fetchOneSource(url, base) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const r = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: ctrl.signal,
    });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const data = await r.json();
    const parsed = parseRatesPayload(data, base);
    if (!parsed) throw new Error('empty rates');
    return {
      ...parsed,
      source: url.includes('er-api') ? 'open.er-api' : 'frankfurter',
    };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Race all sources; first valid payload wins.
 * Falls back to sequential if Promise.any is unavailable (shouldn't happen on Node 18+).
 */
async function fetchRatesForBase(base) {
  const urls = SOURCES.map((build) => build(base));
  const attempts = urls.map((url) =>
    fetchOneSource(url, base).catch((e) => {
      const err = new Error(`${url} → ${e.message || e}`);
      err.url = url;
      throw err;
    })
  );

  try {
    return await Promise.any(attempts);
  } catch (agg) {
    const details = (agg?.errors || []).map((e) => e.message || String(e));
    const err = new Error('All FX sources failed');
    err.details = details;
    throw err;
  }
}

/**
 * If INR base fails (some APIs limit bases), fetch USD then invert to INR-relative rates.
 * Result shape: rates[CODE] = units of CODE per 1 INR (same as frankfurter/er-api when base=INR).
 */
async function fetchViaUsdPivot() {
  const usdPayload = await fetchRatesForBase('USD');
  const usdRates = usdPayload.rates || {};
  const usdPerInr = usdRates.INR;
  if (!(usdPerInr > 0)) {
    throw new Error('USD payload missing INR');
  }
  // 1 INR = usdPerInr USD
  // 1 INR = usdPerInr * (CODE per 1 USD) CODE  when rates are CODE per 1 USD
  const rates = { USD: usdPerInr };
  for (const [code, perUsd] of Object.entries(usdRates)) {
    if (code === 'INR' || code === 'USD') continue;
    const n = Number(perUsd);
    if (n > 0) rates[code] = usdPerInr * n;
  }
  return {
    base: 'INR',
    date: usdPayload.date,
    rates,
    source: `${usdPayload.source}+usd-pivot`,
  };
}

/**
 * GET /api/fx/latest?from=INR
 * Proxies free FX APIs so the browser never hits CORS / redirect issues.
 * Cached 10 minutes per base for fast dashboard loads.
 */
router.get('/latest', async (req, res) => {
  const base = String(req.query.from || req.query.base || 'INR')
    .trim()
    .toUpperCase();

  if (!/^[A-Z]{3}$/.test(base)) {
    return res.status(400).json({ error: 'Invalid currency code' });
  }

  const cached = cache.get(base);
  if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
    return res.json({ ...cached.payload, cached: true });
  }

  try {
    let payload;
    try {
      payload = await fetchRatesForBase(base);
    } catch (primary) {
      // INR is often unsupported as base on ECB-style APIs — pivot via USD
      if (base === 'INR') {
        payload = await fetchViaUsdPivot();
      } else {
        throw primary;
      }
    }

    cache.set(base, { at: Date.now(), payload });
    return res.json({ ...payload, cached: false });
  } catch (e) {
    console.error('FX proxy failed', e.details || e.message || e);
    // Stale cache fallback if available
    if (cached?.payload) {
      return res.json({ ...cached.payload, cached: true, stale: true });
    }
    return res.status(502).json({
      error: 'Could not load live exchange rates. Try again shortly.',
      details: process.env.NODE_ENV === 'development' ? e.details || e.message : undefined,
    });
  }
});

export default router;
