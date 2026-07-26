import { createContext, useCallback, useContext, useMemo, useState } from 'react';

const STORAGE_KEY = 'sanchiva.displayCurrency';

/** Currencies available for app-wide display symbol */
export const DISPLAY_CURRENCIES = [
  { code: 'INR', symbol: '₹', label: 'Indian Rupee', locale: 'en-IN' },
  { code: 'USD', symbol: '$', label: 'US Dollar', locale: 'en-US' },
  { code: 'EUR', symbol: '€', label: 'Euro', locale: 'en-IE' },
  { code: 'GBP', symbol: '£', label: 'British Pound', locale: 'en-GB' },
  { code: 'AED', symbol: 'د.إ', label: 'UAE Dirham', locale: 'en-AE' },
  { code: 'JPY', symbol: '¥', label: 'Japanese Yen', locale: 'ja-JP' },
  { code: 'AUD', symbol: 'A$', label: 'Australian Dollar', locale: 'en-AU' },
  { code: 'CAD', symbol: 'C$', label: 'Canadian Dollar', locale: 'en-CA' },
  { code: 'SGD', symbol: 'S$', label: 'Singapore Dollar', locale: 'en-SG' },
  { code: 'CHF', symbol: 'CHF', label: 'Swiss Franc', locale: 'de-CH' },
  { code: 'CNY', symbol: '¥', label: 'Chinese Yuan', locale: 'zh-CN' },
  { code: 'HKD', symbol: 'HK$', label: 'Hong Kong Dollar', locale: 'zh-HK' },
];

const DEFAULT = DISPLAY_CURRENCIES[0];

export function getCurrencyMeta(code) {
  return DISPLAY_CURRENCIES.find((c) => c.code === code) || DEFAULT;
}

export function readStoredCurrency() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw && DISPLAY_CURRENCIES.some((c) => c.code === raw)) return raw;
  } catch {
    /* ignore */
  }
  return DEFAULT.code;
}

export function writeStoredCurrency(code) {
  try {
    localStorage.setItem(STORAGE_KEY, code);
  } catch {
    /* ignore */
  }
}

/**
 * Module-level currency so formatCurrency() (non-hook) always reads the active code.
 * CurrencyProvider keeps this in sync and re-renders the tree on change.
 */
let activeCurrencyCode = typeof localStorage !== 'undefined' ? readStoredCurrency() : DEFAULT.code;

export function getActiveCurrencyCode() {
  return activeCurrencyCode;
}

export function getActiveCurrencyMeta() {
  return getCurrencyMeta(activeCurrencyCode);
}

export function getCurrencySymbol() {
  return getActiveCurrencyMeta().symbol;
}

const CurrencyContext = createContext(null);

export function CurrencyProvider({ children }) {
  const [currency, setCurrencyState] = useState(() => readStoredCurrency());

  // Keep module-level in sync for formatCurrency
  activeCurrencyCode = currency;

  const setCurrency = useCallback((code) => {
    const meta = getCurrencyMeta(code);
    activeCurrencyCode = meta.code;
    writeStoredCurrency(meta.code);
    setCurrencyState(meta.code);
  }, []);

  const meta = useMemo(() => getCurrencyMeta(currency), [currency]);

  const value = useMemo(
    () => ({
      currency: meta.code,
      symbol: meta.symbol,
      label: meta.label,
      locale: meta.locale,
      meta,
      currencies: DISPLAY_CURRENCIES,
      setCurrency,
    }),
    [meta, setCurrency]
  );

  return <CurrencyContext.Provider value={value}>{children}</CurrencyContext.Provider>;
}

export function useCurrency() {
  const ctx = useContext(CurrencyContext);
  if (!ctx) {
    // Fallback outside provider (e.g. landing) — still works for formatCurrency
    const meta = getActiveCurrencyMeta();
    return {
      currency: meta.code,
      symbol: meta.symbol,
      label: meta.label,
      locale: meta.locale,
      meta,
      currencies: DISPLAY_CURRENCIES,
      setCurrency: () => {},
    };
  }
  return ctx;
}
