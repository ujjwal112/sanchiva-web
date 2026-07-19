// Production: set VITE_API_URL to your API origin if split hosting
// Same-origin (Render): leave empty
export const API_ORIGIN = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '');
const BASE = `${API_ORIGIN}/api`;

const ACCESS_KEY = 'sanchiva_access_token';
const REFRESH_KEY = 'sanchiva_refresh_token';

export function getAccessToken() {
  return localStorage.getItem(ACCESS_KEY);
}
export function getRefreshToken() {
  return localStorage.getItem(REFRESH_KEY);
}
export function setTokens(access, refresh) {
  if (access) localStorage.setItem(ACCESS_KEY, access);
  if (refresh) localStorage.setItem(REFRESH_KEY, refresh);
}
export function clearTokens() {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

let refreshPromise = null;

async function refreshAccessToken() {
  if (refreshPromise) return refreshPromise;
  refreshPromise = (async () => {
    const refresh = getRefreshToken();
    if (!refresh) throw new Error('No refresh token');
    const res = await fetch(`${BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      clearTokens();
      throw new Error(data.error || 'Session expired');
    }
    setTokens(data.access_token, data.refresh_token);
    return data.access_token;
  })().finally(() => {
    refreshPromise = null;
  });
  return refreshPromise;
}

async function request(path, options = {}, retry = true) {
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  const access = getAccessToken();
  if (access) headers.Authorization = `Bearer ${access}`;

  const res = await fetch(`${BASE}${path}`, { ...options, headers });
  const data = await res.json().catch(() => ({}));

  if (res.status === 401 && retry && getRefreshToken() && !path.startsWith('/auth/')) {
    try {
      await refreshAccessToken();
      return request(path, options, false);
    } catch {
      clearTokens();
      if (!window.location.pathname.startsWith('/login')) {
        window.location.href = '/login';
      }
      throw new Error(data.error || 'Session expired');
    }
  }

  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: 'POST', body: JSON.stringify(body) }),
  put: (path, body) => request(path, { method: 'PUT', body: JSON.stringify(body) }),
  del: (path) => request(path, { method: 'DELETE' }),
};

export function formatCurrency(n) {
  const num = Number(n) || 0;
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(num);
}

export function formatDate(d) {
  if (!d) return '—';
  const x = new Date(d);
  return x.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

/**
 * Subtitle under event name: style + type, e.g. wedding + Hindu → "Hindu Wedding".
 * Without style: just the event type ("Birthday").
 */
export function formatEventStyleLabel(eventType, subType) {
  const type = String(eventType || '').trim();
  const style = String(subType || '').trim();
  const typeLabel = type
    ? type.charAt(0).toUpperCase() + type.slice(1).toLowerCase()
    : '';
  if (style && typeLabel) return `${style} ${typeLabel}`;
  if (style) return style;
  return typeLabel || '—';
}

export const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

export function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
