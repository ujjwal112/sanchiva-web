import { NavLink, useLocation } from 'react-router-dom';
import Logo from './Logo';

const links = [
  { to: '/dashboard', label: 'Dashboard', icon: '◈', end: true },
  { to: '/daily-expense', label: 'Daily Expense', icon: '₹' },
  { to: '/loans-credit', label: 'Loans / Credit Card', icon: '◫' },
  { to: '/monetary', label: 'Monetary', icon: '◎' },
  { to: '/events', label: 'Events', icon: '✦' },
  { to: '/about', label: 'About', icon: 'ⓘ' },
];

export default function Sidebar({ open, onClose }) {
  const { pathname } = useLocation();

  return (
    <>
      {open && <div className="overlay" onClick={onClose} />}
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand">
          <Logo size={42} className="brand-logo" />
          <div>
            <h1>Sanchiva</h1>
            <span>Everything that matters</span>
          </div>
        </div>
        <ul className="nav-list">
          {links.map((l) => (
            <li className="nav-item" key={l.to}>
              <NavLink
                to={l.to}
                end={l.end}
                onClick={onClose}
                className={({ isActive }) => {
                  if (l.to === '/events' && pathname.startsWith('/events')) return 'active';
                  return isActive ? 'active' : '';
                }}
              >
                <span className="nav-icon">{l.icon}</span>
                {l.label}
              </NavLink>
            </li>
          ))}
        </ul>
        <div className="card sidebar-footer">
          <div className="sidebar-footer__logo">
            <Logo size={28} />
          </div>
          <p className="sidebar-footer__motto">Everything that matters — one place.</p>
          <p className="muted sidebar-footer__by">Developed by Ujjwal Gupta</p>
        </div>
      </aside>
    </>
  );
}
