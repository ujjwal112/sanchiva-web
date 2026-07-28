import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import UserMenu from './UserMenu';
import { resizeAllCharts } from './Charts';

const titles = {
  '/dashboard': { title: 'Dashboard', sub: 'Overview of expenses, loans & money flow' },
  '/daily-expense': { title: 'Daily Expense', sub: 'Log spends and review week / month insights' },
  '/loans-credit': { title: 'Loans & Credit Cards', sub: 'EMIs, loan progress and card spends' },
  '/monetary': { title: 'Monetary', sub: 'Live currency & metals, income, assets and money given' },
  '/events': { title: 'Events', sub: 'Create events and manage your list' },
  '/about': {
    title: 'About Sanchiva',
    sub: 'Everything that matters, one place',
  },
};

const COLLAPSE_KEY = 'sanchiva.sidebarCollapsed';

function titleForPath(pathname) {
  if (pathname.startsWith('/events/') && pathname !== '/events') {
    return { title: 'Event details', sub: 'Overview, charts, todos and guests' };
  }
  return titles[pathname] || titles['/dashboard'];
}

function readCollapsed() {
  try {
    return localStorage.getItem(COLLAPSE_KEY) === '1';
  } catch {
    return false;
  }
}

export default function Layout() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const { pathname } = useLocation();
  const meta = titleForPath(pathname);

  useEffect(() => {
    try {
      localStorage.setItem(COLLAPSE_KEY, collapsed ? '1' : '0');
    } catch {
      /* ignore */
    }
  }, [collapsed]);

  // Reflow Chart.js when sidebar width animates (esp. expand — canvas was too wide)
  useEffect(() => {
    const delays = [0, 50, 120, 220, 360, 450];
    const timers = delays.map((ms) =>
      window.setTimeout(() => {
        try {
          window.dispatchEvent(new Event('resize'));
        } catch {
          /* ignore */
        }
        resizeAllCharts();
      }, ms)
    );
    return () => timers.forEach((id) => clearTimeout(id));
  }, [collapsed]);

  const toggleCollapse = () => setCollapsed((c) => !c);

  const onMenuToggle = () => {
    if (typeof window !== 'undefined' && window.matchMedia('(max-width: 720px)').matches) {
      setMobileOpen(true);
    } else {
      toggleCollapse();
    }
  };

  return (
    <div
      className={`app-shell${collapsed ? ' sidebar-collapsed' : ''}${mobileOpen ? ' sidebar-drawer-open' : ''}`}
    >
      <Sidebar open={mobileOpen} onClose={() => setMobileOpen(false)} collapsed={collapsed} />
      <main className="main">
        <div className="topbar">
          <div className="topbar-left">
            <button
              type="button"
              className="menu-toggle"
              onClick={onMenuToggle}
              aria-label={collapsed ? 'Expand sidebar' : 'Toggle menu'}
              title={collapsed ? 'Expand sidebar' : 'Collapse or open menu'}
            >
              ☰
            </button>
            <div>
              <h2>{meta.title}</h2>
              <p>{meta.sub}</p>
            </div>
          </div>
          <div className="topbar-right">
            <UserMenu />
          </div>
        </div>
        <Outlet />
      </main>
    </div>
  );
}
