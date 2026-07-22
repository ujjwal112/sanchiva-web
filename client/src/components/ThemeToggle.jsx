import { useTheme } from '../theme/ThemeContext';

function SunIcon() {
  return (
    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" aria-hidden>
      <circle cx="12" cy="12" r="3.5" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M12 2.8v2M12 19.2v2M4.3 12H2.3M21.7 12h-2M5.8 5.8l1.4 1.4M16.8 16.8l1.4 1.4M18.2 5.8l-1.4 1.4M7.2 16.8l-1.4 1.4"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function MoonIcon() {
  return (
    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" aria-hidden>
      <path
        d="M20.2 14.1A7.6 7.6 0 0 1 9.9 3.8 7.9 7.9 0 1 0 20.2 14.1Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/**
 * Theme switch: OFF = light (sun), ON = dark (moon). No text labels.
 */
export default function ThemeToggle({ className = '' }) {
  const { isDark, setTheme } = useTheme();

  const onToggle = () => {
    setTheme(isDark ? 'light' : 'dark');
  };

  return (
    <button
      type="button"
      className={`theme-switch ${isDark ? 'is-on' : 'is-off'} ${className}`.trim()}
      role="switch"
      aria-checked={isDark}
      aria-label={isDark ? 'Dark theme on — switch to light' : 'Light theme on — switch to dark'}
      title={isDark ? 'Dark theme' : 'Light theme'}
      onClick={onToggle}
    >
      <span className="theme-switch-track">
        <span className="theme-switch-thumb" aria-hidden>
          {isDark ? <MoonIcon /> : <SunIcon />}
        </span>
      </span>
    </button>
  );
}
