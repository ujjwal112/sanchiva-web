import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { API_ORIGIN, clearTokens, getAccessToken, getRefreshToken, setTokens } from '../api';
import { isNativeApp, listenNativeOAuthReturn, openNativeOAuth } from './nativeOAuth';

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

  // Android APK: system browser Google OAuth → deep link back with tokens
  useEffect(() => {
    let unsub = () => {};
    let handling = false;
    listenNativeOAuthReturn(async (result) => {
      if (handling) return;
      handling = true;
      if (result.error) {
        window.location.replace(`/login?error=${encodeURIComponent(result.error)}`);
        return;
      }
      try {
        setTokens(result.access, result.refresh);
        setLoading(true);
        await loadMe();
        window.location.replace('/dashboard');
      } catch {
        window.location.replace('/login?error=native_login_failed');
      }
    }).then((fn) => {
      unsub = fn || (() => {});
    });
    return () => unsub();
  }, [loadMe]);

  const loginWithProvider = async (provider) => {
    // APK: open system browser for Google account picker, then return to app
    if (isNativeApp()) {
      try {
        await openNativeOAuth(provider);
      } catch (e) {
        console.error('Native OAuth open failed', e);
        const base = API_ORIGIN || window.location.origin;
        window.location.href = `${base}/api/auth/${provider}?client=android`;
      }
      return;
    }
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
