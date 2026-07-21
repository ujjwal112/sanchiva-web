import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { API_ORIGIN, clearTokens, getAccessToken, getRefreshToken, setTokens } from '../api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const logout = useCallback(async () => {
    const access = getAccessToken();
    const refresh = getRefreshToken();
    try {
      if (access) {
        await fetch(`${API_ORIGIN}/api/auth/logout`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${access}`,
          },
          body: JSON.stringify({ refresh_token: refresh }),
        });
      }
    } catch {
      /* ignore */
    }
    clearTokens();
    setUser(null);
  }, []);

  const loadMe = useCallback(async () => {
    const access = getAccessToken();
    if (!access) {
      setUser(null);
      setLoading(false);
      return;
    }
    try {
      let res = await fetch(`${API_ORIGIN}/api/auth/me`, {
        headers: { Authorization: `Bearer ${access}` },
      });
      if (res.status === 401) {
        const refresh = getRefreshToken();
        if (!refresh) throw new Error('no refresh');
        const r = await fetch(`${API_ORIGIN}/api/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: refresh }),
        });
        if (!r.ok) throw new Error('refresh failed');
        const data = await r.json();
        setTokens(data.access_token, data.refresh_token);
        setUser(data.user);
        setLoading(false);
        return;
      }
      if (!res.ok) throw new Error('me failed');
      const me = await res.json();
      setUser(me);
    } catch {
      clearTokens();
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMe();
  }, [loadMe]);

  const loginWithProvider = (provider) => {
    window.location.href = `${API_ORIGIN}/api/auth/${provider}`;
  };

  const loginAsGuest = useCallback(async () => {
    const res = await fetch(`${API_ORIGIN}/api/auth/guest`, { method: 'POST' });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || 'Guest login failed');
    setTokens(data.access_token, data.refresh_token);
    setUser(data.user);
    return data.user;
  }, []);

  const loginWithPassword = useCallback(async ({ email, password }) => {
    const res = await fetch(`${API_ORIGIN}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || 'Login failed');
    setTokens(data.access_token, data.refresh_token);
    setUser(data.user);
    return data.user;
  }, []);

  const registerWithPassword = useCallback(async ({ name, email, password, confirm_password }) => {
    const res = await fetch(`${API_ORIGIN}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email, password, confirm_password }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || 'Signup failed');
    setTokens(data.access_token, data.refresh_token);
    setUser(data.user);
    return data.user;
  }, []);

  const completeLogin = (access, refresh) => {
    setTokens(access, refresh);
    return loadMe();
  };

  const value = useMemo(
    () => ({
      user,
      loading,
      isAuthenticated: !!user,
      isGuest: user?.provider === 'guest',
      loginWithProvider,
      loginAsGuest,
      loginWithPassword,
      registerWithPassword,
      completeLogin,
      logout,
      refreshUser: loadMe,
    }),
    [user, loading, logout, loadMe, loginAsGuest, loginWithPassword, registerWithPassword]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
