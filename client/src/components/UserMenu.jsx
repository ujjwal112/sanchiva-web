import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { useCurrency } from '../currency/CurrencyContext';

export default function UserMenu() {
  const { user, logout } = useAuth();
  const { currency, symbol, currencies, setCurrency } = useCurrency();
  const [open, setOpen] = useState(false);
  const [currencyOpen, setCurrencyOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const onDoc = (e) => {
      if (ref.current && !ref.current.contains(e.target)) {
        setOpen(false);
        setCurrencyOpen(false);
      }
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, []);

  if (!user) return null;

  const isGuest = user.provider === 'guest';
  const displayName = isGuest ? 'Guest User' : user.name || user.email;
  const initial = (displayName || 'G').trim().charAt(0).toUpperCase();
  const current = currencies.find((c) => c.code === currency) || currencies[0];

  return (
    <div className="user-menu" ref={ref}>
      <button
        type="button"
        className="user-menu-trigger"
        onClick={() => {
          setOpen((v) => !v);
          setCurrencyOpen(false);
        }}
        aria-expanded={open}
      >
        {user.picture && !isGuest ? (
          <img src={user.picture} alt="" className="user-avatar" referrerPolicy="no-referrer" />
        ) : (
          <span className={`user-avatar user-avatar-fallback ${isGuest ? 'guest' : ''}`}>{initial}</span>
        )}
        <span className="user-menu-name">{displayName}</span>
        <span className="user-menu-caret">{open ? '▴' : '▾'}</span>
      </button>
      {open && (
        <div className="user-menu-dropdown">
          <div className="user-menu-section">
            <p className="user-menu-section-label">Display currency</p>
            <button
              type="button"
              className="user-currency-btn"
              onClick={() => setCurrencyOpen((v) => !v)}
              aria-expanded={currencyOpen}
            >
              <span className="user-currency-sym">{symbol}</span>
              <span className="user-currency-meta">
                <strong>{current.code}</strong>
                <span className="muted">{current.label}</span>
              </span>
              <span className="user-menu-caret">{currencyOpen ? '▴' : '▾'}</span>
            </button>
            {currencyOpen && (
              <div className="user-currency-list" role="listbox" aria-label="Select display currency">
                {currencies.map((c) => (
                  <button
                    key={c.code}
                    type="button"
                    role="option"
                    aria-selected={c.code === currency}
                    className={`user-currency-option${c.code === currency ? ' is-active' : ''}`}
                    onClick={() => {
                      setCurrency(c.code);
                      setCurrencyOpen(false);
                    }}
                  >
                    <span className="user-currency-sym">{c.symbol}</span>
                    <span>
                      <strong>{c.code}</strong>
                      <span className="muted">{c.label}</span>
                    </span>
                    {c.code === currency && <span className="user-currency-check">✓</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
          <button
            type="button"
            className="user-logout-btn"
            onClick={() => {
              setOpen(false);
              setCurrencyOpen(false);
              // Hard redirect to landing inside logout — avoids /login flash
              void logout({ redirectTo: '/' });
            }}
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
}
