import { useTheme } from '../theme/ThemeContext';

const ICON_VIEWBOX = '0 0 20 20';

function SunIcon() {
  return (
    <svg
      className="theme-switch-icon"
      viewBox={ICON_VIEWBOX}
      width="14"
      height="14"
      fill="none"
      aria-hidden
    >
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
    <svg
      className="theme-switch-icon"
      viewBox={ICON_VIEWBOX}
      width="14"
      height="14"
      fill="none"
      aria-hidden
    >
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
 * Theme switch: OFF = light (sun), ON = dark (moon).
 * Temporarily disabled — theme stays on current (default light).
 */
export default function ThemeToggle({ className = '' }) {
  const { isDark } = useTheme();

  return (
    <button
      type="button"
      className={`theme-switch theme-switch--disabled ${isDark ? 'is-on' : 'is-off'} ${className}`.trim()}
      role="switch"
      aria-checked={isDark}
      aria-disabled="true"
      disabled
      aria-label="Theme switch (temporarily disabled)"
      title="Theme switch is temporarily disabled"
    >
      <span className="theme-switch-track" aria-hidden>
        <span className="theme-switch-thumb" key={isDark ? 'dark' : 'light'}>
          {isDark ? <MoonIcon /> : <SunIcon />}
        </span>
      </span>
    </button>
  );
}
