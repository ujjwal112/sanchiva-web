import { NavLink, useLocation } from 'react-router-dom';
import Logo from './Logo';
import ThemeToggle from './ThemeToggle';
import { useCurrency } from '../currency/CurrencyContext';

export default function Sidebar({ open, onClose, collapsed }) {
  const { pathname } = useLocation();
  const { symbol: currencySymbol } = useCurrency();

  const links = [
    { to: '/dashboard', label: 'Dashboard', icon: '◈', end: true },
    { to: '/daily-expense', label: 'Daily Expense', icon: currencySymbol || '₹' },
    { to: '/loans-credit', label: 'Loans / Credit Card', icon: '◫' },
    { to: '/monetary', label: 'Monetary', icon: '◎' },
    { to: '/splits', label: 'Splits', icon: '⇋' },
    { to: '/events', label: 'Events', icon: '✦' },
    { to: '/about', label: 'About', icon: 'ⓘ' },
  ];

  return (
    <>
      {open && <div className="overlay" onClick={onClose} />}
      <aside
        className={`sidebar${open ? ' open' : ''}${collapsed ? ' is-collapsed' : ''}`}
        aria-label="Main navigation"
      >
        <div className="brand">
          <div className="brand-identity">
            <Logo size={collapsed ? 34 : 40} className="brand-logo" />
            <div className="brand-text">
              <h1>Sanchiva</h1>
              <span>Everything that matters</span>
            </div>
          </div>
          <div className="brand-actions">
            <ThemeToggle className="sidebar-theme-toggle" />
          </div>
        </div>

        <ul className="nav-list">
          {links.map((l) => (
            <li className="nav-item" key={l.to}>
              <NavLink
                to={l.to}
                end={l.end}
                title={l.label}
                onClick={onClose}
                className={({ isActive }) => {
                  if (l.to === '/events' && pathname.startsWith('/events')) return 'active';
                  if (l.to === '/splits' && pathname.startsWith('/splits')) return 'active';
                  return isActive ? 'active' : '';
                }}
              >
                <span className="nav-icon" aria-hidden>
                  {l.icon}
                </span>
                <span className="nav-label">{l.label}</span>
              </NavLink>
            </li>
          ))}
        </ul>

        <div className="card sidebar-footer">
          <div className="sidebar-footer__logo">
            <Logo size={28} />
          </div>
          <p className="sidebar-footer__motto">Everything that matters, one place.</p>
          <p className="muted sidebar-footer__by">Developed by Ujjwal Gupta</p>
        </div>
      </aside>
    </>
  );
}
