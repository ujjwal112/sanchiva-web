import { Router } from 'express';

const router = Router();

const TROY_OZ_TO_GRAM = 31.1034768;
/** COMEX copper (HG) is quoted USD per pound on gold-api.com */
const LB_TO_GRAM = 453.59237;

const METALS = [
  { code: 'XAU', key: 'gold', name: 'Gold', symbol: 'Au', quoteUnit: 'oz', gramsPerQuote: TROY_OZ_TO_GRAM },
  { code: 'XAG', key: 'silver', name: 'Silver', symbol: 'Ag', quoteUnit: 'oz', gramsPerQuote: TROY_OZ_TO_GRAM },
  { code: 'XPT', key: 'platinum', name: 'Platinum', symbol: 'Pt', quoteUnit: 'oz', gramsPerQuote: TROY_OZ_TO_GRAM },
  { code: 'XPD', key: 'palladium', name: 'Palladium', symbol: 'Pd', quoteUnit: 'oz', gramsPerQuote: TROY_OZ_TO_GRAM },
  // Copper available as HG on free gold-api.com (USD / lb)
  { code: 'HG', key: 'copper', name: 'Copper', symbol: 'Cu', quoteUnit: 'lb', gramsPerQuote: LB_TO_GRAM },
];

/**
 * Major countries — live spot converted to local currency.
 * premium: typical retail/import spread over pure international spot (indicative).
 */
const COUNTRIES = [
  { country: 'United States', code: 'US', currency: 'USD', symbol: '$', premium: 1.0 },
  { country: 'India', code: 'IN', currency: 'INR', symbol: '₹', premium: 1.012 },
  { country: 'United Arab Emirates', code: 'AE', currency: 'AED', symbol: 'د.إ', premium: 1.004 },
  { country: 'United Kingdom', code: 'GB', currency: 'GBP', symbol: '£', premium: 1.006 },
  { country: 'Eurozone', code: 'EU', currency: 'EUR', symbol: '€', premium: 1.005 },
  { country: 'Singapore', code: 'SG', currency: 'SGD', symbol: 'S$', premium: 1.003 },
  { country: 'Hong Kong', code: 'HK', currency: 'HKD', symbol: 'HK$', premium: 1.002 },
  { country: 'China', code: 'CN', currency: 'CNY', symbol: '¥', premium: 1.008 },
  { country: 'Japan', code: 'JP', currency: 'JPY', symbol: '¥', premium: 1.004 },
  { country: 'Australia', code: 'AU', currency: 'AUD', symbol: 'A$', premium: 1.005 },
  { country: 'Canada', code: 'CA', currency: 'CAD', symbol: 'C$', premium: 1.004 },
  { country: 'Switzerland', code: 'CH', currency: 'CHF', symbol: 'CHF', premium: 1.003 },
  { country: 'Saudi Arabia', code: 'SA', currency: 'SAR', symbol: '﷼', premium: 1.006 },
  { country: 'Turkey', code: 'TR', currency: 'TRY', symbol: '₺', premium: 1.01 },
  { country: 'South Africa', code: 'ZA', currency: 'ZAR', symbol: 'R', premium: 1.007 },
  { country: 'Thailand', code: 'TH', currency: 'THB', symbol: '฿', premium: 1.005 },
];

/**
 * India city / state premiums on pure (24K / fine) price.
 * Real local retail varies; these are typical market spreads over spot.
 */
const INDIA_CITIES = [
  { city: 'Mumbai', state: 'Maharashtra', premium: 1.0 },
  { city: 'Delhi', state: 'Delhi', premium: 1.008 },
  { city: 'Bengaluru', state: 'Karnataka', premium: 1.006 },
  { city: 'Chennai', state: 'Tamil Nadu', premium: 0.997 },
  { city: 'Kolkata', state: 'West Bengal', premium: 1.004 },
  { city: 'Hyderabad', state: 'Telangana', premium: 1.005 },
  { city: 'Ahmedabad', state: 'Gujarat', premium: 0.998 },
  { city: 'Pune', state: 'Maharashtra', premium: 1.002 },
  { city: 'Jaipur', state: 'Rajasthan', premium: 1.003 },
  { city: 'Kochi', state: 'Kerala', premium: 1.001 },
  { city: 'Lucknow', state: 'Uttar Pradesh', premium: 1.007 },
  { city: 'Chandigarh', state: 'Chandigarh', premium: 1.006 },
  { city: 'Indore', state: 'Madhya Pradesh', premium: 1.004 },
  { city: 'Bhubaneswar', state: 'Odisha', premium: 1.005 },
  { city: 'Guwahati', state: 'Assam', premium: 1.01 },
  { city: 'Patna', state: 'Bihar', premium: 1.009 },
  { city: 'Surat', state: 'Gujarat', premium: 0.999 },
  { city: 'Coimbatore', state: 'Tamil Nadu', premium: 0.998 },
  { city: 'Nagpur', state: 'Maharashtra', premium: 1.003 },
  { city: 'Visakhapatnam', state: 'Andhra Pradesh', premium: 1.004 },
];

/** Serve cached payload if upstream fails or within TTL */
let cache = { at: 0, payload: null };
const CACHE_TTL_MS = 5 * 60 * 1000;
const STALE_MAX_MS = 60 * 60 * 1000;

const FETCH_HEADERS = {
  Accept: 'application/json',
  'User-Agent': 'Sanchiva/1.0 (metals proxy)',
};

async function fetchJson(url, timeoutMs = 12000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, { headers: FETCH_HEADERS, signal: ctrl.signal });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(timer);
  }
}

/** Full USD→currency rates map (includes INR). */
async function fetchUsdRates() {
  const sources = [
    async () => {
      const data = await fetchJson('https://open.er-api.com/v6/latest/USD');
      if (data.rates?.INR) return { USD: 1, ...data.rates };
      return null;
    },
    async () => {
      const data = await fetchJson('https://api.frankfurter.dev/v1/latest?base=USD');
      if (data.rates?.INR) return { USD: 1, ...data.rates };
      return null;
    },
    async () => {
      const data = await fetchJson('https://api.frankfurter.app/latest?from=USD');
      if (data.rates?.INR) return { USD: 1, ...data.rates };
      return null;
    },
  ];
  for (const src of sources) {
    try {
      const rates = await src();
      if (rates?.INR) {
        return Object.fromEntries(
          Object.entries(rates).map(([k, v]) => [k, Number(v)]).filter(([, v]) => Number.isFinite(v))
        );
      }
    } catch {
      /* next */
    }
  }
  return null;
}

/**
 * Primary: gold-api.com
 * Fallback: goldprice.org for gold/silver
 */
async function fetchMetalSpot(code) {
  try {
    const data = await fetchJson(`https://api.gold-api.com/price/${code}`);
    if (data?.price != null) {
      return {
        price: Number(data.price),
        updatedAt: data.updatedAt || null,
        source: 'gold-api',
      };
    }
  } catch {
    /* fallback */
  }

  try {
    await new Promise((r) => setTimeout(r, 400));
    const data = await fetchJson(`https://api.gold-api.com/price/${code}`, 15000);
    if (data?.price != null) {
      return {
        price: Number(data.price),
        updatedAt: data.updatedAt || null,
        source: 'gold-api-retry',
      };
    }
  } catch {
    /* fallback */
  }

  if (code === 'XAU' || code === 'XAG') {
    try {
      const data = await fetchJson('https://data-asg.goldprice.org/dbXRates/USD', 12000);
      const item = data?.items?.[0];
      if (item) {
        const price = code === 'XAU' ? Number(item.xauPrice) : Number(item.xagPrice);
        if (price > 0) {
          return {
            price,
            updatedAt: data.date || null,
            source: 'goldprice.org',
          };
        }
      }
    } catch {
      /* give up */
    }
  }

  throw new Error(`No price for ${code}`);
}

function buildCountries(purePerGramUsd, purePerGramInr, usdRates, metalKey) {
  return COUNTRIES.map((c) => {
    const fx = c.currency === 'USD' ? 1 : usdRates[c.currency];
    if (fx == null || !Number.isFinite(fx)) return null;

    const pureLocalPerGram = purePerGramUsd * fx;
    const purityFactor = metalKey === 'gold' ? 22 / 24 : 1;
    const perGramLocal = pureLocalPerGram * purityFactor * c.premium;
    const perGramInr = purePerGramInr * purityFactor * c.premium;

    return {
      country: c.country,
      code: c.code,
      currency: c.currency,
      symbol: c.symbol,
      perGramLocal,
      perGramInr,
      carat: metalKey === 'gold' ? '22K' : 'Fine',
      premium: c.premium,
    };
  }).filter(Boolean);
}

function buildIndiaCities(purePerGramInr, metalKey) {
  return INDIA_CITIES.map((c) => ({
    city: c.city,
    state: c.state,
    perGramInr:
      metalKey === 'gold'
        ? purePerGramInr * (22 / 24) * c.premium
        : purePerGramInr * c.premium,
    carat: metalKey === 'gold' ? '22K' : 'Fine',
    premium: c.premium,
  }));
}

function buildMetals(usdRates, metalResults) {
  const usdInr = usdRates.INR;
  const metals = {};

  for (const row of metalResults) {
    if (!row.ok || row.price == null) continue;
    const usdSpot = Number(row.price);
    if (!Number.isFinite(usdSpot) || usdSpot <= 0) continue;

    const quoteUnit = row.meta.quoteUnit || 'oz';
    const gramsPerQuote = row.meta.gramsPerQuote || TROY_OZ_TO_GRAM;
    const inrSpot = usdSpot * usdInr;
    const purePerGramUsd = usdSpot / gramsPerQuote;
    const purePerGramInr = inrSpot / gramsPerQuote;

    const carats =
      row.meta.key === 'gold'
        ? {
            k24: purePerGramInr,
            k22: purePerGramInr * (22 / 24),
            k18: purePerGramInr * (18 / 24),
            k14: purePerGramInr * (14 / 24),
          }
        : {
            fine: purePerGramInr,
          };

    // Keep usdPerOz / inrPerOz for troy-oz metals; copper uses usdPerLb
    const isLb = quoteUnit === 'lb';

    metals[row.meta.key] = {
      code: row.meta.code,
      name: row.meta.name,
      symbol: row.meta.symbol,
      quoteUnit,
      quoteUnitLabel: isLb ? 'lb' : 'oz',
      usdSpot,
      inrSpot,
      usdPerOz: isLb ? null : usdSpot,
      inrPerOz: isLb ? null : inrSpot,
      usdPerLb: isLb ? usdSpot : null,
      inrPerLb: isLb ? inrSpot : null,
      purePerGramInr,
      purePerGramUsd,
      carats,
      countries: buildCountries(purePerGramUsd, purePerGramInr, usdRates, row.meta.key),
      cities: buildIndiaCities(purePerGramInr, row.meta.key),
      updatedAt: row.updatedAt || null,
      source: row.source || null,
    };
  }
  return metals;
}

/**
 * GET /api/metals/latest
 * Live spots + country-wise rates + India city/state rates.
 */
router.get('/latest', async (_req, res) => {
  const now = Date.now();

  if (cache.payload && now - cache.at < CACHE_TTL_MS) {
    return res.json({ ...cache.payload, cached: true, cacheAgeMs: now - cache.at });
  }

  try {
    const [usdRates, ...metalResults] = await Promise.all([
      fetchUsdRates(),
      ...METALS.map((m) =>
        fetchMetalSpot(m.code)
          .then((j) => ({
            ok: true,
            meta: m,
            price: j.price,
            updatedAt: j.updatedAt,
            source: j.source,
          }))
          .catch((e) => ({ ok: false, meta: m, error: e.message }))
      ),
    ]);

    if (!usdRates?.INR) {
      if (cache.payload && now - cache.at < STALE_MAX_MS) {
        return res.json({
          ...cache.payload,
          cached: true,
          stale: true,
          cacheAgeMs: now - cache.at,
          warning: 'Using cached rates; live FX unavailable',
        });
      }
      return res.status(502).json({ error: 'Could not load USD exchange rates for metal conversion' });
    }

    const metals = buildMetals(usdRates, metalResults);

    if (!Object.keys(metals).length) {
      if (cache.payload && now - cache.at < STALE_MAX_MS) {
        return res.json({
          ...cache.payload,
          cached: true,
          stale: true,
          cacheAgeMs: now - cache.at,
          warning: 'Using cached rates; live metal spots unavailable',
        });
      }
      const details = metalResults
        .filter((r) => !r.ok)
        .map((r) => `${r.meta?.code}: ${r.error}`)
        .join('; ');
      return res.status(502).json({
        error: 'Could not load metal spot prices',
        details: process.env.NODE_ENV !== 'production' ? details : undefined,
      });
    }

    const payload = {
      unit: { oz: 'troy ounce', gram: 'gram' },
      usdInr: usdRates.INR,
      fx: {
        USD: 1,
        INR: usdRates.INR,
        AED: usdRates.AED,
        GBP: usdRates.GBP,
        EUR: usdRates.EUR,
        SGD: usdRates.SGD,
        HKD: usdRates.HKD,
        CNY: usdRates.CNY,
        JPY: usdRates.JPY,
        AUD: usdRates.AUD,
        CAD: usdRates.CAD,
        CHF: usdRates.CHF,
        SAR: usdRates.SAR,
        TRY: usdRates.TRY,
        ZAR: usdRates.ZAR,
        THB: usdRates.THB,
      },
      metals,
      countries: COUNTRIES.map(({ country, code, currency, symbol }) => ({
        country,
        code,
        currency,
        symbol,
      })),
      cities: INDIA_CITIES.map(({ city, state }) => ({ city, state })),
      note: 'Rates are indicative: live international spot converted via FX, with typical country/city premiums. Retail jewellery prices may differ (making charges, taxes).',
      fetchedAt: new Date().toISOString(),
      cached: false,
    };

    cache = { at: now, payload };
    return res.json(payload);
  } catch (e) {
    console.error('metals proxy failed', e);
    if (cache.payload && now - cache.at < STALE_MAX_MS) {
      return res.json({
        ...cache.payload,
        cached: true,
        stale: true,
        cacheAgeMs: now - cache.at,
        warning: e.message || 'Using cached rates after error',
      });
    }
    return res.status(502).json({ error: e.message || 'Could not load metal prices' });
  }
});

export default router;
