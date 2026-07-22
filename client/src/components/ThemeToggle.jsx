import { useTheme } from '../theme/ThemeContext';

/**
 * Theme switch: ON = dark, OFF = light.
 */
export default function ThemeToggle({ className = '' }) {
  const { isDark, setTheme } = useTheme();

  const onToggle = () => {
    setTheme(isDark ? 'light' : 'dark');
  };

  return (
    <label
      className={`theme-switch ${isDark ? 'is-on' : 'is-off'} ${className}`.trim()}
      title={isDark ? 'Dark theme on' : 'Light theme (dark off)'}
    >
      <span className="theme-switch-text theme-switch-text--off" aria-hidden>
        Light
      </span>
      <button
        type="button"
        className="theme-switch-track"
        role="switch"
        aria-checked={isDark}
        aria-label={isDark ? 'Dark theme on — click for light' : 'Light theme on — click for dark'}
        onClick={onToggle}
      >
        <span className="theme-switch-thumb" aria-hidden />
      </button>
      <span className="theme-switch-text theme-switch-text--on" aria-hidden>
        Dark
      </span>
    </label>
  );
}
