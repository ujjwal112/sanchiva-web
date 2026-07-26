import { Router } from 'express';

const router = Router();

/** Free rate sources (no API key). Tried in order. */
const SOURCES = [
  (base) => `https://api.frankfurter.dev/v1/latest?base=${encodeURIComponent(base)}`,
  (base) => `https://api.frankfurter.app/latest?from=${encodeURIComponent(base)}`,
  (base) => `https://open.er-api.com/v6/latest/${encodeURIComponent(base)}`,
];

/**
 * GET /api/fx/latest?from=INR
 * Proxies free FX APIs so the browser never hits CORS / redirect issues.
 */
router.get('/latest', async (req, res) => {
  const base = String(req.query.from || req.query.base || 'INR')
    .trim()
    .toUpperCase();

  if (!/^[A-Z]{3}$/.test(base)) {
    return res.status(400).json({ error: 'Invalid currency code' });
  }

  const errors = [];

  for (const buildUrl of SOURCES) {
    const url = buildUrl(base);
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 12000);
      const r = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal: ctrl.signal,
      }).finally(() => clearTimeout(timer));
      if (!r.ok) {
        errors.push(`${url} → HTTP ${r.status}`);
        continue;
      }
      const data = await r.json();

      // Frankfurter shape: { base, date, rates }
      // open.er-api shape: { base_code, time_last_update_utc, rates, result }
      const rates = data.rates || {};
      const from = (data.base || data.base_code || base).toUpperCase();
      const date =
        data.date ||
        (data.time_last_update_utc
          ? String(data.time_last_update_utc).slice(0, 10)
          : new Date().toISOString().slice(0, 10));

      if (!rates || typeof rates !== 'object' || !Object.keys(rates).length) {
        errors.push(`${url} → empty rates`);
        continue;
      }

      return res.json({
        base: from,
        date,
        rates,
        source: url.includes('er-api') ? 'open.er-api' : 'frankfurter',
      });
    } catch (e) {
      errors.push(`${url} → ${e.message || e}`);
    }
  }

  console.error('FX proxy failed', errors);
  return res.status(502).json({
    error: 'Could not load live exchange rates. Try again shortly.',
    details: process.env.NODE_ENV === 'development' ? errors : undefined,
  });
});

export default router;
