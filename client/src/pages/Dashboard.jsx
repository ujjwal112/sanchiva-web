import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, API_ORIGIN, formatCurrency, MONTHS } from '../api';
import { PieChart, BarChart, LineChart, MultiBarChart, categoryChartData } from '../components/Charts';
import { useCurrency } from '../currency/CurrencyContext';

/** Compact “open / view more” control for live rate cards */
function ViewMoreIconLink({ to, label }) {
  return (
    <Link to={to} className="dash-live-more" aria-label={label} title={label}>
      <svg
        className="dash-live-more__icon"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.1"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
      >
        <path d="M7 17L17 7" />
        <path d="M8 7h9v9" />
      </svg>
    </Link>
  );
}

/** Currencies shown on dashboard (1 unit → INR) */
const DASH_FX_CODES = ['USD', 'EUR', 'GBP', 'JPY'];
const FX_SYMBOLS = { USD: '$', EUR: '€', GBP: '£', JPY: '¥' };
const FX_NAMES = {
  USD: 'US Dollar',
  EUR: 'Euro',
  GBP: 'British Pound',
  JPY: 'Japanese Yen',
};

const FX_CACHE_KEY = 'sanchiva.dash.fx.v2';
const FX_CACHE_TTL_MS = 10 * 60 * 1000;

/** Metals shown on dashboard (country board rates) */
const DASH_METALS = [
  { key: 'gold', label: 'Gold' },
  { key: 'silver', label: 'Silver' },
  { key: 'platinum', label: 'Platinum' },
  { key: 'palladium', label: 'Palladium' },
];

function formatFxRate(n) {
  if (n == null || Number.isNaN(n)) return '-';
  if (n >= 100) return n.toLocaleString('en-IN', { maximumFractionDigits: 2 });
  if (n >= 1) return n.toLocaleString('en-IN', { maximumFractionDigits: 2 });
  return n.toLocaleString('en-IN', { maximumFractionDigits: 4 });
}

function formatMoney(n, currencyCode) {
  if (n == null || Number.isNaN(n)) return '-';
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: currencyCode || 'INR',
      maximumFractionDigits: currencyCode === 'JPY' ? 0 : 2,
    }).format(n);
  } catch {
    return `${Number(n).toLocaleString(undefined, { maximumFractionDigits: 2 })} ${currencyCode || ''}`;
  }
}

/** Pick country board row matching profile display currency (e.g. USD → United States) */
function pickCountryForCurrency(countries, displayCurrency) {
  const list = countries || [];
  if (!list.length) return null;
  const code = String(displayCurrency || 'INR').toUpperCase();
  return (
    list.find((c) => String(c.currency || '').toUpperCase() === code) ||
    list.find((c) => c.code === 'IN') ||
    list[0] ||
    null
  );
}

function buildMetalRows(metalsPayload, displayCurrency) {
  const metals = metalsPayload?.metals || metalsPayload || {};
  return DASH_METALS.map(({ key, label }) => {
    const m = metals[key];
    if (!m) {
      return {
        key,
        label,
        rateLocal: null,
        carat: key === 'gold' ? '22K' : 'Fine',
        currency: displayCurrency || 'INR',
        countryName: null,
      };
    }
    const country = pickCountryForCurrency(m.countries, displayCurrency);
    return {
      key,
      label,
      // Country-local rate / g (matches Monetary metals board for that currency)
      rateLocal: country?.perGramLocal ?? country?.perGramInr ?? null,
      carat: country?.carat || (key === 'gold' ? '22K' : 'Fine'),
      currency: country?.currency || displayCurrency || 'INR',
      countryName: country?.country || null,
      countryCode: country?.code || null,
    };
  });
}

export default function Dashboard() {
  const { currency, symbol: currencySymbol } = useCurrency();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  const [fxRows, setFxRows] = useState(null);
  const [fxLoading, setFxLoading] = useState(true);
  const [fxError, setFxError] = useState('');

  const [metalsPayload, setMetalsPayload] = useState(null);
  const [metalRows, setMetalRows] = useState(null);
  const [metalCountry, setMetalCountry] = useState('India');
  const [metalsLoading, setMetalsLoading] = useState(true);
  const [metalsError, setMetalsError] = useState('');

  useEffect(() => {
    api
      .get('/dashboard')
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);

  // Live FX: USD / EUR / GBP / JPY vs INR — paint session cache first, revalidate fast
  useEffect(() => {
    let cancelled = false;

    const rowsFromRates = (ratesIn) => {
      const rates = { INR: 1, ...(ratesIn || {}) };
      // API: rates[USD] = units of USD per 1 INR → invert for INR per 1 USD
      return DASH_FX_CODES.map((code) => {
        const perInr = rates[code];
        const inrPerUnit = perInr > 0 ? 1 / perInr : null;
        return {
          code,
          name: FX_NAMES[code] || code,
          symbol: FX_SYMBOLS[code] || code,
          inrPerUnit,
        };
      });
    };

    let hadCache = false;
    try {
      const raw = sessionStorage.getItem(FX_CACHE_KEY);
      if (raw) {
        const cached = JSON.parse(raw);
        if (cached?.at && Date.now() - cached.at < FX_CACHE_TTL_MS && cached.rates) {
          setFxRows(rowsFromRates(cached.rates));
          setFxLoading(false);
          hadCache = true;
        }
      }
    } catch {
      /* ignore bad cache */
    }

    (async () => {
      if (!hadCache) setFxLoading(true);
      setFxError('');
      try {
        const ctrl = new AbortController();
        const timer = window.setTimeout(() => ctrl.abort(), 8000);
        const res = await fetch(`${API_ORIGIN || ''}/api/fx/latest?from=INR`, {
          headers: { Accept: 'application/json' },
          signal: ctrl.signal,
        }).finally(() => window.clearTimeout(timer));
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json.error || 'Could not load FX rates');
        const rates = json.rates || {};
        if (!cancelled) {
          setFxRows(rowsFromRates(rates));
          setFxError('');
          try {
            sessionStorage.setItem(FX_CACHE_KEY, JSON.stringify({ at: Date.now(), rates }));
          } catch {
            /* quota */
          }
        }
      } catch (e) {
        if (!cancelled && !hadCache) {
          setFxError(
            e.name === 'AbortError'
              ? 'Rates timed out — open Live currency to retry'
              : e.message || 'Could not load currency rates'
          );
        }
      } finally {
        if (!cancelled) setFxLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  // Live metals payload (once) — country rows re-derived when profile currency changes
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setMetalsLoading(true);
      setMetalsError('');
      try {
        const res = await fetch(`${API_ORIGIN || ''}/api/metals/latest`, {
          headers: { Accept: 'application/json' },
          cache: 'no-store',
        });
        const json = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(json.error || 'Could not load metal rates');
        if (!cancelled) {
          setMetalsPayload(json);
          setMetalsError('');
        }
      } catch (e) {
        if (!cancelled) {
          setMetalsError(e.message || 'Could not load metal rates');
          setMetalsPayload(null);
        }
      } finally {
        if (!cancelled) setMetalsLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // Map profile display currency → country metal rates for that currency
  useEffect(() => {
    if (!metalsPayload) {
      setMetalRows(null);
      return;
    }
    const rows = buildMetalRows(metalsPayload, currency);
    setMetalRows(rows);
    const first = rows.find((r) => r.countryName);
    setMetalCountry(first?.countryName || currency || 'India');
  }, [metalsPayload, currency]);

  if (error) {
    return (
      <div className="card">
        <h3>Could not load dashboard</h3>
        <p className="muted">{error}</p>
        <p className="muted" style={{ marginTop: '0.5rem' }}>
          Ensure the API and PostgreSQL are running.
        </p>
      </div>
    );
  }

  if (!data) return <div className="card">Loading dashboard…</div>;

  const k = data.kpis;
  const monthPie = categoryChartData(data.monthExpenseCard?.byCategory);
  const bankLabels = (data.loanBankCard?.banks || []).map((b) => b.bank);
  const bankValues = (data.loanBankCard?.banks || []).map((b) => b.totalEmi);
  const closure = data.loanClosureYearCard || [];
  const assetPie = categoryChartData(data.assetsByType);
  const givenPie = categoryChartData(data.moneyGivenByPerson);

  return (
    <div className="stack-sm" style={{ gap: '1.1rem', display: 'flex', flexDirection: 'column' }}>
      {/* Section 1 — KPIs */}
      <div className="grid grid-4 stagger">
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>This month spent</h3>
              <p className="muted">
                {MONTHS[(data.month || 1) - 1]} {data.year}
              </p>
            </div>
            <div className="kpi-icon" key={`spend-${currency}`} title={currency}>
              {currencySymbol || currency}
            </div>
          </div>
          <div className="metric" key={`spend-m-${currency}`}>
            {formatCurrency(k.monthExpenseTotal)}
          </div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Income</h3>
              <p className="muted">Salary & sources</p>
            </div>
            <div className="kpi-icon">↑</div>
          </div>
          <div className="metric" key={`income-m-${currency}`}>
            {formatCurrency(k.monthIncome)}
          </div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Balance</h3>
              <p className="muted">Income − spends</p>
            </div>
            <div className="kpi-icon">◎</div>
          </div>
          <div className="metric" key={`bal-m-${currency}`}>
            {formatCurrency(k.monthBalance)}
          </div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Monthly EMI</h3>
              <p className="muted">
                {k.activeLoans} active · {k.closedLoans} closed
              </p>
            </div>
            <div className="kpi-icon">◫</div>
          </div>
          <div className="metric" key={`emi-m-${currency}`}>
            {formatCurrency(k.monthlyEmi)}
          </div>
        </div>
      </div>

      {/* Section 2 — Live currency · Live metals · Quick stats */}
      <div className="grid grid-3">
        <div className="card dash-live-card">
          <div className="dash-live-card__head">
            <div>
              <h3>Live currency</h3>
              <p className="muted">1 unit → INR</p>
            </div>
            <ViewMoreIconLink to="/monetary?tab=currency" label="View more live currency" />
          </div>
          <div className="dash-live-list">
            {fxLoading && !fxRows && <p className="muted dash-live-empty">Loading rates…</p>}
            {fxError && !fxRows && <p className="muted dash-live-empty">{fxError}</p>}
            {fxRows?.map((row) => (
              <div key={row.code} className="stat-row dash-live-row">
                <span className="dash-live-row__label">
                  <span className="dash-live-code">{row.code}</span>
                  <span className="muted dash-live-name">{row.name}</span>
                </span>
                <strong>
                  {row.symbol}1 = ₹{formatFxRate(row.inrPerUnit)}
                </strong>
              </div>
            ))}
          </div>
        </div>

        <div className="card dash-live-card">
          <div className="dash-live-card__head">
            <div>
              <h3>Live metals</h3>
              <p className="muted">
                {metalCountry || 'India'} · {currency || 'INR'} / g
              </p>
            </div>
            <ViewMoreIconLink to="/monetary?tab=metals" label="View more live metals" />
          </div>
          <div className="dash-live-list">
            {metalsLoading && !metalRows && <p className="muted dash-live-empty">Loading metals…</p>}
            {metalsError && !metalRows && <p className="muted dash-live-empty">{metalsError}</p>}
            {metalRows?.map((row) => (
              <div key={row.key} className="stat-row dash-live-row">
                <span className="dash-live-row__label">
                  <span className="dash-live-code">{row.label}</span>
                  <span className="muted dash-live-name">{row.carat}</span>
                </span>
                <strong>{formatMoney(row.rateLocal, row.currency)}</strong>
              </div>
            ))}
          </div>
        </div>

        <div className="card dash-live-card dash-quick-stats">
          <div className="dash-live-card__head">
            <div>
              <h3>Quick stats</h3>
              <p className="muted">At a glance</p>
            </div>
            <span className="dash-live-more dash-quick-stats__badge" aria-hidden title="Quick stats">
              <svg
                className="dash-live-more__icon"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.1"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M4 19V5" />
                <path d="M4 19h16" />
                <path d="M8 16v-5" />
                <path d="M12 16V8" />
                <path d="M16 16v-3" />
              </svg>
            </span>
          </div>
          <div className="dash-live-list dash-quick-stats__list">
            <div className="stat-row dash-live-row dash-quick-stats__row">
              <span className="dash-live-row__label">
                <span className="dash-live-code">CC spends</span>
                <span className="muted dash-live-name">This month</span>
              </span>
              <strong>{formatCurrency(k.ccSpendMonth)}</strong>
            </div>
            <div className="stat-row dash-live-row dash-quick-stats__row">
              <span className="dash-live-row__label">
                <span className="dash-live-code">Events</span>
                <span className="muted dash-live-name">Tracked</span>
              </span>
              <strong>{k.eventsCount}</strong>
            </div>
            <div className="stat-row dash-live-row dash-quick-stats__row">
              <span className="dash-live-row__label">
                <span className="dash-live-code">Assets</span>
                <span className="muted dash-live-name">Total value</span>
              </span>
              <strong>{formatCurrency(k.assetsTotal)}</strong>
            </div>
            <div className="stat-row dash-live-row dash-quick-stats__row">
              <span className="dash-live-row__label">
                <span className="dash-live-code">Money lent</span>
                <span className="muted dash-live-name">Outstanding</span>
              </span>
              <strong>{formatCurrency(k.moneyGivenTotal)}</strong>
            </div>
          </div>
        </div>
      </div>

      {/* Expense charts */}
      <div className="grid grid-2">
        <div className="card">
          <h3>Month-wise expense · category pie</h3>
          <p className="muted">
            Total {formatCurrency(data.monthExpenseCard?.total)} in {MONTHS[(data.month || 1) - 1]}
          </p>
          <PieChart labels={monthPie.labels} values={monthPie.values} doughnut />
        </div>
        <div className="card">
          <h3>Expense trend</h3>
          <p className="muted">Last ~6 months</p>
          <LineChart
            labels={(data.expenseTrend || []).map((t) => t.label)}
            values={(data.expenseTrend || []).map((t) => t.total)}
          />
        </div>
      </div>

      {/* Loans section */}
      <div className="grid grid-3">
        <div className="card">
          <h3>Loans this month</h3>
          <p className="muted">Total obligation vs deducted vs remaining</p>
          <div className="stat-row">
            <span>Total loan amount</span>
            <strong>{formatCurrency(data.loanMonthCard?.totalLoanAmount)}</strong>
          </div>
          <div className="stat-row">
            <span>Deducted this month</span>
            <strong>{formatCurrency(data.loanMonthCard?.deductedThisMonth)}</strong>
          </div>
          <div className="stat-row">
            <span>Remaining to deduct</span>
            <strong>{formatCurrency(data.loanMonthCard?.remainingToDeduct)}</strong>
          </div>
          <PieChart
            labels={['Deducted this month', 'Remaining']}
            values={[
              data.loanMonthCard?.deductedThisMonth || 0,
              data.loanMonthCard?.remainingToDeduct || 0,
            ]}
            doughnut
          />
        </div>

        <div className="card">
          <h3>EMI by deduction bank</h3>
          <p className="muted">
            Active {data.loanBankCard?.totalActiveLoans} · Monthly EMI{' '}
            {formatCurrency(data.loanBankCard?.totalMonthlyEmi)} · Closed{' '}
            {data.loanBankCard?.closedLoansCount}
          </p>
          <BarChart labels={bankLabels} values={bankValues} label="EMI / bank" />
        </div>

        <div className="card">
          <h3>Loan closure by year</h3>
          <p className="muted">Closing schedule overview</p>
          <MultiBarChart
            labels={closure.map((c) => String(c.year))}
            datasets={[
              { label: 'Closing', values: closure.map((c) => c.closingCount) },
              { label: 'Closed', values: closure.map((c) => c.closedCount) },
              { label: 'Active', values: closure.map((c) => c.activeCount) },
            ]}
          />
        </div>
      </div>

      {/* Last section — Assets + Money given only */}
      <div className="grid grid-2">
        <div className="card">
          <h3>Assets mix</h3>
          <p className="muted">Total {formatCurrency(k.assetsTotal)}</p>
          <PieChart labels={assetPie.labels} values={assetPie.values} />
        </div>
        <div className="card">
          <h3>Money given to people</h3>
          <p className="muted">Total {formatCurrency(k.moneyGivenTotal)}</p>
          <PieChart labels={givenPie.labels} values={givenPie.values} doughnut />
        </div>
      </div>
    </div>
  );
}
