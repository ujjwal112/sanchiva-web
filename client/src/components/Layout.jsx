import { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Logo from './Logo';
import UserMenu from './UserMenu';

const titles = {
  '/': { title: 'Dashboard', sub: 'Overview of expenses, loans & money flow' },
  '/daily-expense': { title: 'Daily Expense', sub: 'Log spends and review week / month insights' },
  '/loans-credit': { title: 'Loans & Credit Cards', sub: 'EMIs, loan progress and card spends' },
  '/monetary': { title: 'Monetary', sub: 'Income, assets and money given to people' },
  '/events': { title: 'Events', sub: 'Create events and manage your list' },
  '/about': {
    title: 'About Sanchiva',
    sub: 'Everything that matters — one place',
  },
};

function titleForPath(pathname) {
  if (pathname.startsWith('/events/') && pathname !== '/events') {
    return { title: 'Event details', sub: 'Overview, charts, todos and guests' };
  }
  return titles[pathname] || titles['/'];
}

export default function Layout() {
  const [open, setOpen] = useState(false);
  const { pathname } = useLocation();
  const meta = titleForPath(pathname);

  return (
    <div className="app-shell">
      <Sidebar open={open} onClose={() => setOpen(false)} />
      <main className="main">
        <div className="topbar">
          <div className="topbar-left">
            <button className="menu-toggle" onClick={() => setOpen(true)} aria-label="Open menu">
              ☰
            </button>
            <Logo size={36} className="topbar-logo" />
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
