import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../auth/AuthContext';

export default function UserMenu() {
  const { user, logout } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const onDoc = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, []);

  if (!user) return null;

  const initial = (user.name || user.email || 'U').trim().charAt(0).toUpperCase();

  return (
    <div className="user-menu" ref={ref}>
      <button
        type="button"
        className="user-menu-trigger"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
      >
        {user.picture ? (
          <img src={user.picture} alt="" className="user-avatar" referrerPolicy="no-referrer" />
        ) : (
          <span className="user-avatar user-avatar-fallback">{initial}</span>
        )}
        <span className="user-menu-name">{user.name || user.email}</span>
        <span className="user-menu-caret">{open ? '▴' : '▾'}</span>
      </button>
      {open && (
        <div className="user-menu-dropdown">
          <div className="user-menu-meta">
            <strong>{user.name}</strong>
            <span className="muted">{user.email}</span>
            <span className="badge">{user.provider}</span>
          </div>
          <button
            type="button"
            className="btn btn-danger btn-sm user-logout-btn"
            onClick={() => {
              setOpen(false);
              logout().then(() => {
                window.location.href = '/login';
              });
            }}
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
}
