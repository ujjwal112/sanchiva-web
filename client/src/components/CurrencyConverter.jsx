import { useCallback, useEffect, useMemo, useState } from 'react';
import { API_ORIGIN } from '../api';
import { GlassSelect } from './ui';

/** Proxied free rates: GET /api/fx/latest?from=INR */
function ratesUrl(base) {
  const origin = API_ORIGIN || '';
  return `${origin}/api/fx/latest?from=${encodeURIComponent(base)}`;
}

const BOARD_CODES = [
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'AUD',
  'CAD',
  'SGD',
  'CHF',
  'CNY',
  'HKD',
  'NZD',
  'THB',
  'MYR',
  'KRW',
  'IDR',
  'AED',
];

const POPULAR = ['INR', ...BOARD_CODES];

const SYMBOLS = {
  INR: '₹',
  USD: '$',
  EUR: '€',
  GBP: '£',
  JPY: '¥',
  AUD: 'A$',
  CAD: 'C$',
  SGD: 'S$',
  CHF: 'CHF',
  CNY: '¥',
  HKD: 'HK$',
  NZD: 'NZ$',
  THB: '฿',
  MYR: 'RM',
  KRW: '₩',
  IDR: 'Rp',
  AED: 'د.إ',
};

const NAMES = {
  USD: 'US Dollar',
  EUR: 'Euro',
  GBP: 'British Pound',
  JPY: 'Japanese Yen',
  AUD: 'Australian Dollar',
  CAD: 'Canadian Dollar',
  SGD: 'Singapore Dollar',
  CHF: 'Swiss Franc',
  CNY: 'Chinese Yuan',
  HKD: 'Hong Kong Dollar',
  NZD: 'New Zealand Dollar',
  THB: 'Thai Baht',
  MYR: 'Malaysian Ringgit',
  KRW: 'South Korean Won',
  IDR: 'Indonesian Rupiah',
  AED: 'UAE Dirham',
  INR: 'Indian Rupee',
};

function formatRate(n) {
  if (n == null || Number.isNaN(n)) return '-';
  if (n >= 100) return n.toLocaleString(undefined, { maximumFractionDigits: 2 });
  if (n >= 1) return n.toLocaleString(undefined, { maximumFractionDigits: 4 });
  return n.toLocaleString(undefined, { maximumFractionDigits: 6 });
}

function formatMoney(n, currency) {
  if (n == null || Number.isNaN(n)) return '-';
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(n);
  } catch {
    const sym = SYMBOLS[currency] || currency;
    return `${sym} ${n.toLocaleString(undefined, { maximumFractionDigits: 2 })}`;
  }
}

export default function CurrencyConverter() {
  const [amount, setAmount] = useState('1000');
  const [from, setFrom] = useState('INR');
  const [to, setTo] = useState('USD');
  /** rates vs INR: rates[USD] = units of USD per 1 INR */
  const [inrRates, setInrRates] = useState(null);
  const [date, setDate] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [updatedAt, setUpdatedAt] = useState(null);

  const fetchInrRates = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch(ratesUrl('INR'));
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || 'Could not load rates');
      setInrRates({ INR: 1, ...(data.rates || {}) });
      setDate(data.date || '');
      setUpdatedAt(new Date());
    } catch (e) {
      setError(e.message || 'Could not load live rates');
      setInrRates(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchInrRates();
    const id = window.setInterval(fetchInrRates, 15 * 60 * 1000);
    return () => clearInterval(id);
  }, [fetchInrRates]);

  const currencyOptions = useMemo(() => {
    const available = inrRates ? Object.keys(inrRates) : POPULAR;
    const preferred = POPULAR.filter((c) => available.includes(c));
    const rest = available.filter((c) => !preferred.includes(c)).sort();
    const keys = inrRates ? [...preferred, ...rest] : POPULAR;
    return keys.map((code) => ({
      value: code,
      label: `${SYMBOLS[code] ? `${SYMBOLS[code]} ` : ''}${code}`,
    }));
  }, [inrRates]);

  useEffect(() => {
    if (!inrRates) return;
    if (from !== 'INR' && inrRates[from] == null) setFrom('INR');
    if (to !== 'INR' && inrRates[to] == null) {
      setTo(inrRates.USD != null ? 'USD' : Object.keys(inrRates).find((k) => k !== 'INR') || 'USD');
    }
  }, [inrRates, from, to]);

  /** Cross-rate using INR as pivot: amount_FROM → TO */
  const crossRate = useCallback(
    (fromCode, toCode) => {
      if (!inrRates) return null;
      if (fromCode === toCode) return 1;
      const fromPerInr = fromCode === 'INR' ? 1 : inrRates[fromCode];
      const toPerInr = toCode === 'INR' ? 1 : inrRates[toCode];
      if (fromPerInr == null || toPerInr == null || fromPerInr === 0) return null;
      // 1 FROM = (1/fromPerInr) INR = (toPerInr/fromPerInr) TO
      return toPerInr / fromPerInr;
    },
    [inrRates]
  );

  const amountNum = Number(String(amount).replace(/,/g, ''));
  const validAmount = Number.isFinite(amountNum) && amountNum >= 0;
  const unitRate = crossRate(from, to);
  const converted = validAmount && unitRate != null ? amountNum * unitRate : null;

  /** Board rows: 1 foreign = X INR (more readable for INR users) */
  const boardRows = useMemo(() => {
    if (!inrRates) return [];
    return BOARD_CODES.filter((code) => inrRates[code] != null && inrRates[code] > 0).map((code) => {
      const perInr = inrRates[code]; // 1 INR = perInr CODE
      const inrPerUnit = 1 / perInr; // 1 CODE = inrPerUnit INR
      return {
        code,
        name: NAMES[code] || code,
        symbol: SYMBOLS[code] || code,
        inrPerUnit,
        perInr,
      };
    });
  }, [inrRates]);

  const swap = () => {
    setFrom(to);
    setTo(from);
  };

  return (
    <div className="card fx-converter">
      <div className="fx-converter__head">
        <div>
          <h3>Live currency</h3>
        </div>
        <button
          type="button"
          className="btn btn-ghost btn-sm fx-refresh"
          onClick={fetchInrRates}
          disabled={loading}
          title="Refresh rates"
        >
          {loading ? 'Updating…' : '↻ Refresh'}
        </button>
      </div>

      {error && <div className="fx-error">{error}</div>}

      <div className="fx-split">
        {/* Left: converter */}
        <section className="fx-split__left" aria-label="Currency converter">
          <h4 className="fx-panel-title">Converter</h4>

          <div className="fx-converter__fields">
            <div className="field">
              <label>Amount</label>
              <input
                type="number"
                min="0"
                step="any"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                aria-label="Amount to convert"
              />
            </div>

            <div className="fx-pair-row">
              <div className="field">
                <label>From</label>
                <GlassSelect
                  value={from}
                  onChange={setFrom}
                  options={currencyOptions}
                  placeholder="From"
                  aria-label="From currency"
                />
              </div>
              <button type="button" className="fx-swap" onClick={swap} title="Swap" aria-label="Swap currencies">
                ⇄
              </button>
              <div className="field">
                <label>To</label>
                <GlassSelect
                  value={to}
                  onChange={setTo}
                  options={currencyOptions}
                  placeholder="To"
                  aria-label="To currency"
                />
              </div>
            </div>
          </div>

          <div className="fx-result">
            <div className="fx-result__label">Converted amount</div>
            <div className="fx-result__value">
              {loading && !inrRates ? 'Loading rates…' : formatMoney(converted, to)}
            </div>
            {unitRate != null && (
              <div className="fx-result__rate">
                1 {from} = {formatRate(unitRate)} {to}
                {date ? ` · ${date}` : ''}
              </div>
            )}
            {updatedAt && (
              <div className="fx-result__meta muted">
                Updated {updatedAt.toLocaleTimeString()} · auto-refresh 15 min
              </div>
            )}
          </div>

          <div className="fx-quick">
            <span className="muted fx-quick__label">Quick picks</span>
            <div className="fx-quick__chips">
              {[
                ['INR', 'USD'],
                ['USD', 'INR'],
                ['EUR', 'INR'],
                ['GBP', 'INR'],
                ['USD', 'EUR'],
              ].map(([a, b]) => (
                <button
                  key={`${a}-${b}`}
                  type="button"
                  className={`fx-chip${from === a && to === b ? ' is-active' : ''}`}
                  onClick={() => {
                    setFrom(a);
                    setTo(b);
                  }}
                >
                  {a} → {b}
                </button>
              ))}
            </div>
          </div>
        </section>

        {/* Right: live rates vs INR */}
        <section className="fx-split__right" aria-label="Live rates versus INR">
          <div className="fx-board-head">
            <h4 className="fx-panel-title">Live rates vs INR</h4>
            <p className="muted fx-board-sub">1 foreign unit in Indian Rupees</p>
          </div>

          <div className="fx-board">
            {loading && !boardRows.length && (
              <div className="fx-board-empty muted">Loading live rates…</div>
            )}
            {!loading && !boardRows.length && (
              <div className="fx-board-empty muted">No rates available</div>
            )}
            {boardRows.map((row) => (
              <button
                key={row.code}
                type="button"
                className={`fx-board-row${to === row.code || from === row.code ? ' is-active' : ''}`}
                onClick={() => {
                  setFrom('INR');
                  setTo(row.code);
                }}
                title={`Convert INR to ${row.code}`}
              >
                <span className="fx-board-code">
                  <span className="fx-board-sym">{row.symbol}</span>
                  <span>
                    <strong>{row.code}</strong>
                    <span className="fx-board-name muted">{row.name}</span>
                  </span>
                </span>
                <span className="fx-board-rate">
                  <strong>₹ {formatRate(row.inrPerUnit)}</strong>
                  <span className="muted">per 1 {row.code}</span>
                </span>
              </button>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
