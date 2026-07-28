import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { API_ORIGIN } from '../api';
import { GlassSelect } from './ui';

function metalsUrl() {
  return `${API_ORIGIN || ''}/api/metals/latest`;
}

const METAL_OPTIONS = [
  { value: 'gold', label: 'Gold (Au)' },
  { value: 'silver', label: 'Silver (Ag)' },
  { value: 'platinum', label: 'Platinum (Pt)' },
  { value: 'palladium', label: 'Palladium (Pd)' },
  { value: 'copper', label: 'Copper (Cu)' },
];

const UNIT_OPTIONS = [
  { value: 'gram', label: 'Gram (g)' },
  { value: '10g', label: '10 grams' },
  { value: 'oz', label: 'Troy ounce' },
];

/** Traditional Indian tola weight used for jewellery gold rates */
const TOLA_GRAMS = 11.6638038;

const GOLD_UNIT_OPTIONS = [
  ...UNIT_OPTIONS,
  { value: 'tola', label: 'Tola (≈11.66 g)' },
];

const GOLD_PURITY = [
  { value: 'k24', label: '24K (pure)' },
  { value: 'k22', label: '22K' },
  { value: 'k18', label: '18K' },
  { value: 'k14', label: '14K' },
];

function formatInr(n) {
  if (n == null || Number.isNaN(n)) return '-';
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 2,
  }).format(n);
}

function formatUsd(n) {
  if (n == null || Number.isNaN(n)) return '-';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 2,
  }).format(n);
}

function formatLocal(n, currency) {
  if (n == null || Number.isNaN(n)) return '-';
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      maximumFractionDigits: currency === 'JPY' ? 0 : 2,
    }).format(n);
  } catch {
    return `${n.toLocaleString(undefined, { maximumFractionDigits: 2 })} ${currency}`;
  }
}

async function fetchMetalsOnce() {
  const res = await fetch(metalsUrl(), {
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(json.error || json.details || `Metal prices failed (${res.status})`);
  }
  if (!json.metals || !Object.keys(json.metals).length) {
    throw new Error('Metal prices response was empty');
  }
  return json;
}

async function fetchMetalsWithRetry() {
  try {
    return await fetchMetalsOnce();
  } catch (first) {
    await new Promise((r) => setTimeout(r, 700));
    try {
      return await fetchMetalsOnce();
    } catch (second) {
      throw second || first;
    }
  }
}

export default function MetalsConverter() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [updatedAt, setUpdatedAt] = useState(null);

  const [metal, setMetal] = useState('gold');
  const [amount, setAmount] = useState('10');
  const [unit, setUnit] = useState('gram');
  const [purity, setPurity] = useState('k22');
  const [boardMode, setBoardMode] = useState('india'); // countries | india — default India states
  const [countryCode, setCountryCode] = useState('IN');
  const [cityKey, setCityKey] = useState('Mumbai');

  /**
   * Match right column height to left content height.
   * List area flex-fills remaining space so no white gap under the board.
   */
  const leftRef = useRef(null);
  const [rightColHeight, setRightColHeight] = useState(null);

  const syncRightHeight = useCallback(() => {
    const left = leftRef.current;
    if (!left) return;
    // Stacked layout: let list use natural/max height
    if (typeof window !== 'undefined' && window.matchMedia('(max-width: 900px)').matches) {
      setRightColHeight(null);
      return;
    }
    // Round up so right never ends short of left (avoids thin white strip)
    const next = Math.ceil(left.getBoundingClientRect().height);
    if (next > 0) {
      setRightColHeight((prev) => (prev === next ? prev : next));
    }
  }, []);

  useLayoutEffect(() => {
    syncRightHeight();
    // Second pass after layout settles (fonts / glass selects)
    const t = window.requestAnimationFrame(() => syncRightHeight());
    return () => window.cancelAnimationFrame(t);
  }, [syncRightHeight, metal, purity, boardMode, data, loading, amount, unit, countryCode, cityKey]);

  useEffect(() => {
    const left = leftRef.current;
    if (!left) return undefined;
    const ro =
      typeof ResizeObserver !== 'undefined'
        ? new ResizeObserver(() => {
            syncRightHeight();
          })
        : null;
    ro?.observe(left);
    window.addEventListener('resize', syncRightHeight);
    return () => {
      ro?.disconnect();
      window.removeEventListener('resize', syncRightHeight);
    };
  }, [syncRightHeight]);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const json = await fetchMetalsWithRetry();
      setData(json);
      setUpdatedAt(new Date());
      if (json.warning) setError(json.warning);
    } catch (e) {
      const msg =
        e?.message === 'Failed to fetch'
          ? 'Could not reach the API. Is the server running on port 5000?'
          : e?.message || 'Could not load metal prices';
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const id = window.setInterval(load, 15 * 60 * 1000);
    return () => clearInterval(id);
  }, [load]);

  const metalData = data?.metals?.[metal] || null;

  const countryOptions = useMemo(() => {
    const list = metalData?.countries || data?.countries || [];
    return list.map((c) => ({
      value: c.code,
      label: `${c.country} (${c.currency || c.code})`,
    }));
  }, [metalData, data]);

  const cityOptions = useMemo(() => {
    const list = metalData?.cities || data?.cities || [];
    return list.map((c) => ({
      value: c.city,
      label: `${c.city}, ${c.state}`,
    }));
  }, [metalData, data]);

  const selectedCountry = useMemo(() => {
    const list = metalData?.countries || [];
    return list.find((c) => c.code === countryCode) || list.find((c) => c.code === 'IN') || list[0] || null;
  }, [metalData, countryCode]);

  const selectedCity = useMemo(() => {
    const list = metalData?.cities || [];
    return list.find((c) => c.city === cityKey) || list[0] || null;
  }, [metalData, cityKey]);

  /** pure price per gram in INR for selected purity (no city/country premium) */
  const purePerGramInr = useMemo(() => {
    if (!metalData) return null;
    if (metal === 'gold') {
      return metalData.carats?.[purity] ?? metalData.purePerGramInr;
    }
    return metalData.purePerGramInr;
  }, [metalData, metal, purity]);

  const unitOptions = metal === 'gold' ? GOLD_UNIT_OPTIONS : UNIT_OPTIONS;

  const grams = useMemo(() => {
    const n = Number(amount);
    if (!Number.isFinite(n) || n < 0) return null;
    if (unit === 'oz') return n * 31.1034768;
    if (unit === '10g') return n * 10;
    if (unit === 'tola') return n * TOLA_GRAMS;
    return n;
  }, [amount, unit]);

  const isCountryMode = boardMode === 'countries' && !!selectedCountry;
  const displayCurrency = isCountryMode ? selectedCountry.currency : 'INR';
  const quoteLabel = metalData?.quoteUnitLabel || (metal === 'copper' ? 'lb' : 'oz');

  /** Country premium vs 22K/fine board baseline */
  const locationPremium = useMemo(() => {
    if (!metalData) return 1;
    const baseline =
      metal === 'gold' ? metalData.carats?.k22 ?? metalData.purePerGramInr : metalData.purePerGramInr;
    if (!baseline || baseline <= 0) return 1;

    if (boardMode === 'india' && selectedCity) {
      return selectedCity.perGramInr / baseline;
    }
    if (selectedCountry) {
      return selectedCountry.perGramInr / baseline;
    }
    return 1;
  }, [metalData, metal, boardMode, selectedCity, selectedCountry]);

  /** 1 USD → display currency (from API fx or derived from country row) */
  const usdToDisplay = useMemo(() => {
    if (!isCountryMode || !selectedCountry) {
      return data?.usdInr ?? null; // INR
    }
    if (selectedCountry.currency === 'USD') return 1;
    if (selectedCountry.currency === 'INR') return data?.usdInr ?? null;
    const fromFx = data?.fx?.[selectedCountry.currency];
    if (fromFx != null && Number(fromFx) > 0) return Number(fromFx);
    // Derive: pure USD/g → local/g via board row (22K/fine with premium)
    if (metalData?.purePerGramUsd > 0 && selectedCountry.perGramLocal > 0) {
      const purityFactor = metal === 'gold' ? 22 / 24 : 1;
      const premium = selectedCountry.premium ?? 1;
      return selectedCountry.perGramLocal / (metalData.purePerGramUsd * purityFactor * premium);
    }
    return null;
  }, [isCountryMode, selectedCountry, data, metalData, metal]);

  const formatDisplay = useCallback(
    (n) => {
      if (n == null || Number.isNaN(n)) return '-';
      if (displayCurrency === 'INR') return formatInr(n);
      return formatLocal(n, displayCurrency);
    },
    [displayCurrency]
  );

  /** Spot chips + conversion in display currency (with location premium when set) */
  const displayRates = useMemo(() => {
    if (!metalData || usdToDisplay == null) return null;
    const prem = locationPremium;
    const pureUsd = metalData.purePerGramUsd;
    const spotUsd = metalData.usdSpot ?? metalData.usdPerOz ?? metalData.usdPerLb;
    const pureLocal = pureUsd * usdToDisplay * prem;
    const spotLocal = spotUsd * usdToDisplay * prem;
    // Selected purity local/g
    let purityLocal = pureLocal;
    if (metal === 'gold') {
      const map = { k24: 1, k22: 22 / 24, k18: 18 / 24, k14: 14 / 24 };
      purityLocal = pureUsd * usdToDisplay * prem * (map[purity] ?? 22 / 24);
    }
    const k22Local = pureUsd * usdToDisplay * prem * (22 / 24);
    // 1 tola at selected gold purity (or pure for non-gold — unused in UI)
    const tolaLocal = purityLocal * TOLA_GRAMS;
    return {
      spotLocal,
      pureLocal,
      purityLocal,
      k22Local,
      tolaLocal,
      perKgLocal: pureLocal * 1000,
      currency: displayCurrency,
      quoteLabel,
    };
  }, [metalData, usdToDisplay, locationPremium, metal, purity, displayCurrency, quoteLabel]);

  const convertedInr = useMemo(() => {
    if (grams == null || purePerGramInr == null) return null;
    return grams * purePerGramInr * locationPremium;
  }, [grams, purePerGramInr, locationPremium]);

  const convertedDisplay = useMemo(() => {
    if (grams == null || !displayRates) return null;
    return grams * displayRates.purityLocal;
  }, [grams, displayRates]);

  const boardCountries = metalData?.countries || [];
  const boardCities = metalData?.cities || [];

  const locationLabel =
    boardMode === 'india' && selectedCity
      ? `${selectedCity.city}, ${selectedCity.state}`
      : selectedCountry
        ? selectedCountry.country
        : '';

  return (
    <div className="card metals-converter">
      <div className="fx-converter__head">
        <div>
          <h3>Live metals</h3>
        </div>
        <button
          type="button"
          className="btn btn-ghost btn-sm fx-refresh"
          onClick={load}
          disabled={loading}
          title="Refresh prices"
        >
          {loading ? 'Updating…' : '↻ Refresh'}
        </button>
      </div>

      {error && <div className="fx-error">{error}</div>}

      <div className="fx-split metals-split">
        <section className="fx-split__left" ref={leftRef} aria-label="Metal converter">
          <h4 className="fx-panel-title">Converter</h4>

          <div className="fx-converter__fields">
            <div className="field">
              <label>Metal</label>
              <GlassSelect
                value={metal}
                onChange={(v) => {
                  setMetal(v);
                  if (v !== 'gold') {
                    setPurity('k22');
                    // Tola is gold-only; reset unit when leaving gold
                    setUnit((u) => (u === 'tola' ? 'gram' : u));
                  }
                }}
                options={METAL_OPTIONS}
                placeholder="Metal"
              />
            </div>

            {metal === 'gold' && (
              <div className="field">
                <label>Purity</label>
                <GlassSelect value={purity} onChange={setPurity} options={GOLD_PURITY} placeholder="Purity" />
              </div>
            )}

            <div className="metals-amount-row">
              <div className="field">
                <label>Amount</label>
                <input
                  type="number"
                  min="0"
                  step="any"
                  inputMode="decimal"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0"
                  aria-label="Metal amount"
                />
              </div>
              <div className="field">
                <label>Unit</label>
                <GlassSelect value={unit} onChange={setUnit} options={unitOptions} placeholder="Unit" />
              </div>
            </div>

            <div className="field">
              <label>Location type</label>
              <div className="metals-mode-toggle">
                <button
                  type="button"
                  className={`fx-chip${boardMode === 'countries' ? ' is-active' : ''}`}
                  onClick={() => setBoardMode('countries')}
                >
                  Country
                </button>
                <button
                  type="button"
                  className={`fx-chip${boardMode === 'india' ? ' is-active' : ''}`}
                  onClick={() => setBoardMode('india')}
                >
                  India state / city
                </button>
              </div>
            </div>

            {boardMode === 'countries' ? (
              <div className="field">
                <label>Country</label>
                <GlassSelect
                  value={selectedCountry?.code || countryCode}
                  onChange={setCountryCode}
                  options={
                    countryOptions.length ? countryOptions : [{ value: 'IN', label: 'India (INR)' }]
                  }
                  placeholder="Country"
                />
              </div>
            ) : (
              <div className="field">
                <label>City / state</label>
                <GlassSelect
                  value={selectedCity?.city || cityKey}
                  onChange={setCityKey}
                  options={
                    cityOptions.length
                      ? cityOptions
                      : [{ value: 'Mumbai', label: 'Mumbai, Maharashtra' }]
                  }
                  placeholder="City"
                />
              </div>
            )}
          </div>

          <div className="fx-result metals-result">
            <div className="fx-result__label">
              Estimated value{locationLabel ? ` · ${locationLabel}` : ''}
              {isCountryMode && selectedCountry?.currency
                ? ` · ${selectedCountry.currency}`
                : ''}
            </div>
            <div className="fx-result__value">
              {loading && !data
                ? 'Loading prices…'
                : formatDisplay(convertedDisplay)}
            </div>
            {isCountryMode &&
              displayCurrency !== 'INR' &&
              convertedInr != null && (
                <div className="fx-result__rate">≈ {formatInr(convertedInr)} INR</div>
              )}
            {metalData && displayRates && (
              <div className="fx-result__rate">
                Spot {metalData.name}: {formatUsd(metalData.usdSpot ?? metalData.usdPerOz ?? metalData.usdPerLb)}{' '}
                / {quoteLabel}
                {' · '}
                {formatDisplay(displayRates.purityLocal)} / g
                {data?.usdInr ? ` · USD/INR ${Number(data.usdInr).toFixed(2)}` : ''}
              </div>
            )}
            {updatedAt && (
              <div className="fx-result__meta muted">
                Updated {updatedAt.toLocaleTimeString()}
                {data?.cached || data?.stale ? ' · cached' : ''} · auto-refresh 15 min
              </div>
            )}
          </div>

          {metalData && displayRates && (
            <div className="metals-spot-grid">
              <div className="metals-spot-chip">
                <span className="muted">
                  {displayCurrency} / {quoteLabel}
                </span>
                <strong>{formatDisplay(displayRates.spotLocal)}</strong>
              </div>
              <div className="metals-spot-chip">
                <span className="muted">USD / {quoteLabel}</span>
                <strong>
                  {formatUsd(metalData.usdSpot ?? metalData.usdPerOz ?? metalData.usdPerLb)}
                </strong>
              </div>
              <div className="metals-spot-chip">
                <span className="muted">Per gram</span>
                <strong>{formatDisplay(displayRates.purityLocal)}</strong>
              </div>
              {metal === 'gold' ? (
                <div className="metals-spot-chip">
                  <span className="muted">
                    1 tola rate
                    {purity === 'k24'
                      ? ' · 24K'
                      : purity === 'k22'
                        ? ' · 22K'
                        : purity === 'k18'
                          ? ' · 18K'
                          : purity === 'k14'
                            ? ' · 14K'
                            : ''}
                  </span>
                  <strong>{formatDisplay(displayRates.tolaLocal)}</strong>
                </div>
              ) : (
                <div className="metals-spot-chip">
                  <span className="muted">Per kg</span>
                  <strong>{formatDisplay(displayRates.perKgLocal)}</strong>
                </div>
              )}
            </div>
          )}
        </section>

        <section
          className="fx-split__right metals-rates"
          aria-label="Metal rates by location"
          style={rightColHeight != null ? { height: `${rightColHeight}px` } : undefined}
        >
          <div className="metals-rates__chrome">
            <h4 className="fx-panel-title metals-rates__title">
              Live rates · {metalData?.name || 'Metal'} ({metal === 'gold' ? '22K' : 'Fine'})
            </h4>

            <div className="metals-mode-toggle metals-rates__mode">
              <button
                type="button"
                className={`fx-chip${boardMode === 'countries' ? ' is-active' : ''}`}
                onClick={() => setBoardMode('countries')}
              >
                Countries
              </button>
              <button
                type="button"
                className={`fx-chip${boardMode === 'india' ? ' is-active' : ''}`}
                onClick={() => setBoardMode('india')}
              >
                India states
              </button>
            </div>

            <div className="metals-tabs metals-metal-tabs">
              {METAL_OPTIONS.map((m) => (
                <button
                  key={m.value}
                  type="button"
                  className={`fx-chip${metal === m.value ? ' is-active' : ''}`}
                  onClick={() => {
                    setMetal(m.value);
                    if (m.value !== 'gold') {
                      setPurity('k22');
                      setUnit((u) => (u === 'tola' ? 'gram' : u));
                    }
                  }}
                >
                  {m.label}
                </button>
              ))}
            </div>
          </div>

          <div className="fx-board metals-board">
            {boardMode === 'countries' && (
              <>
                {loading && !boardCountries.length && (
                  <div className="fx-board-empty muted">Loading country rates…</div>
                )}
                {!loading && !boardCountries.length && (
                  <div className="fx-board-empty muted">No country rates available</div>
                )}
                {boardCountries.map((row) => (
                  <button
                    key={row.code}
                    type="button"
                    className={`fx-board-row${countryCode === row.code ? ' is-active' : ''}`}
                    onClick={() => {
                      setCountryCode(row.code);
                      setBoardMode('countries');
                    }}
                  >
                    <span className="fx-board-code">
                      <span className="fx-board-sym metals-city-sym">{row.code}</span>
                      <span>
                        <strong>{row.country}</strong>
                        <span className="fx-board-name muted">{row.currency}</span>
                      </span>
                    </span>
                    <span className="fx-board-rate">
                      <strong>
                        {row.currency === 'INR'
                          ? formatInr(row.perGramInr)
                          : formatLocal(row.perGramLocal, row.currency)}
                      </strong>
                      <span className="muted">
                        / g · {row.carat}
                        {row.currency !== 'INR' ? ` · ${formatInr(row.perGramInr)}` : ''}
                      </span>
                    </span>
                  </button>
                ))}
              </>
            )}

            {boardMode === 'india' && (
              <>
                {loading && !boardCities.length && (
                  <div className="fx-board-empty muted">Loading city rates…</div>
                )}
                {!loading && !boardCities.length && (
                  <div className="fx-board-empty muted">No city rates available</div>
                )}
                {boardCities.map((row) => (
                  <button
                    key={row.city}
                    type="button"
                    className={`fx-board-row${cityKey === row.city ? ' is-active' : ''}`}
                    onClick={() => {
                      setCityKey(row.city);
                      setBoardMode('india');
                    }}
                  >
                    <span className="fx-board-code">
                      <span className="fx-board-sym metals-city-sym">{row.city.slice(0, 2).toUpperCase()}</span>
                      <span>
                        <strong>{row.city}</strong>
                        <span className="fx-board-name muted">{row.state}</span>
                      </span>
                    </span>
                    <span className="fx-board-rate">
                      <strong>{formatInr(row.perGramInr)}</strong>
                      <span className="muted">/ g · {row.carat}</span>
                    </span>
                  </button>
                ))}
              </>
            )}
          </div>
        </section>
      </div>

      <p className="metals-disclaimer muted">
        Indicative only: international spot converted with live FX and typical country/city
        premiums. Retail jewellery prices may differ (making charges, GST).
      </p>
    </div>
  );
}
