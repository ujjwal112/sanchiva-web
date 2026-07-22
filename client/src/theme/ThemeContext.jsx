import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

const THEME_KEY = 'sanchiva.theme';
const ThemeContext = createContext(null);

function readTheme() {
  try {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved === 'dark' || saved === 'light') return saved;
  } catch {
    /* ignore */
  }
  // Default for the logged-in app: dark theme
  return 'dark';
}

function applyTheme(theme) {
  const root = document.documentElement;
  root.setAttribute('data-theme', theme);
  root.classList.toggle('theme-dark', theme === 'dark');
  root.classList.toggle('theme-light', theme === 'light');
}

export function ThemeProvider({ children }) {
  const [theme, setThemeState] = useState(() => {
    const t = readTheme();
    // Apply ASAP so first paint is correct when possible
    if (typeof document !== 'undefined') applyTheme(t);
    return t;
  });

  useEffect(() => {
    applyTheme(theme);
    try {
      localStorage.setItem(THEME_KEY, theme);
    } catch {
      /* ignore */
    }
  }, [theme]);

  const setTheme = useCallback((next) => {
    const t = next === 'dark' ? 'dark' : 'light';
    // Apply DOM theme immediately so CSS + any readers stay in sync on the same click
    applyTheme(t);
    try {
      localStorage.setItem(THEME_KEY, t);
    } catch {
      /* ignore */
    }
    setThemeState(t);
  }, []);

  const toggleTheme = useCallback(() => {
    setThemeState((prev) => {
      const t = prev === 'dark' ? 'light' : 'dark';
      applyTheme(t);
      try {
        localStorage.setItem(THEME_KEY, t);
      } catch {
        /* ignore */
      }
      return t;
    });
  }, []);

  const value = useMemo(
    () => ({
      theme,
      isDark: theme === 'dark',
      setTheme,
      toggleTheme,
    }),
    [theme, setTheme, toggleTheme]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
