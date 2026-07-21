import { useId } from 'react';

/**
 * Sanchiva logo
 * Meaning: collection, accumulation, preservation, savings, wealth gathered over time.
 * Visual: a protective circle (one place / vault) holding ascending layers of value
 * that gather into a bright core, everything that matters, collected and organized.
 */
export default function Logo({
  size = 40,
  className = '',
  title = 'Sanchiva',
  variant = 'mark', // mark | full
  showWordmark = false,
}) {
  const uid = useId().replace(/:/g, '');
  const id = `sanchiva-${uid}`;
  const markSize = size;

  const Mark = (
    <svg
      className={`sanchiva-logo-mark ${className}`}
      width={markSize}
      height={markSize}
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={title}
    >
      <title>{title}</title>
      <defs>
        <linearGradient id={`${id}-ring`} x1="8" y1="6" x2="56" y2="58" gradientUnits="userSpaceOnUse">
          <stop stopColor="#A78BFA" />
          <stop offset="0.45" stopColor="#7C6CFF" />
          <stop offset="1" stopColor="#22D3EE" />
        </linearGradient>
        <linearGradient id={`${id}-core`} x1="24" y1="20" x2="42" y2="44" gradientUnits="userSpaceOnUse">
          <stop stopColor="#F0ABFC" />
          <stop offset="0.5" stopColor="#7C6CFF" />
          <stop offset="1" stopColor="#22D3EE" />
        </linearGradient>
        <linearGradient id={`${id}-layer`} x1="18" y1="40" x2="46" y2="28" gradientUnits="userSpaceOnUse">
          <stop stopColor="#C4B5FD" stopOpacity="0.95" />
          <stop offset="1" stopColor="#67E8F9" stopOpacity="0.95" />
        </linearGradient>
        <radialGradient id={`${id}-glow`} cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(32 30) rotate(90) scale(18)">
          <stop stopColor="#FFFFFF" stopOpacity="0.55" />
          <stop offset="1" stopColor="#7C6CFF" stopOpacity="0" />
        </radialGradient>
        <filter id={`${id}-soft`} x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="1.2" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Outer vault ring, preservation / one place */}
      <circle cx="32" cy="32" r="28" stroke={`url(#${id}-ring)`} strokeWidth="2.5" opacity="0.95" />
      <circle cx="32" cy="32" r="24.5" stroke="rgba(255,255,255,0.12)" strokeWidth="1" />

      {/* Soft inner glow */}
      <circle cx="32" cy="30" r="16" fill={`url(#${id}-glow)`} />

      {/* Ascending value layers, accumulation / savings over time */}
      <g filter={`url(#${id}-soft)`}>
        {/* Bottom layer (foundation of savings) */}
        <ellipse cx="32" cy="42" rx="14" ry="4.2" fill={`url(#${id}-layer)`} opacity="0.55" />
        {/* Middle layer */}
        <ellipse cx="32" cy="36" rx="11" ry="3.6" fill={`url(#${id}-layer)`} opacity="0.75" />
        {/* Upper layer */}
        <ellipse cx="32" cy="30.5" rx="8" ry="3" fill={`url(#${id}-layer)`} opacity="0.9" />
      </g>

      {/* Collecting paths, streams gathering into the core */}
      <path
        d="M18 38 C22 34, 24 30, 28 26"
        stroke={`url(#${id}-ring)`}
        strokeWidth="1.6"
        strokeLinecap="round"
        opacity="0.7"
      />
      <path
        d="M46 38 C42 34, 40 30, 36 26"
        stroke={`url(#${id}-ring)`}
        strokeWidth="1.6"
        strokeLinecap="round"
        opacity="0.7"
      />

      {/* Bright core, everything valuable, organized */}
      <circle cx="32" cy="24" r="5.5" fill={`url(#${id}-core)`} />
      <circle cx="30.5" cy="22.5" r="1.8" fill="rgba(255,255,255,0.75)" />

      {/* Small value sparks */}
      <circle cx="20" cy="22" r="1.3" fill="#22D3EE" opacity="0.9" />
      <circle cx="44" cy="22" r="1.3" fill="#C4B5FD" opacity="0.9" />
      <circle cx="32" cy="48.5" r="1.1" fill="#F0ABFC" opacity="0.75" />
    </svg>
  );

  if (variant === 'full' || showWordmark) {
    return (
      <div className={`sanchiva-logo-full ${className}`} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.22 }}>
        {Mark}
        <div className="sanchiva-logo-text" style={{ lineHeight: 1.15 }}>
          <div
            className="sanchiva-logo-wordmark"
            style={{
              fontSize: size * 0.42,
              fontWeight: 700,
              letterSpacing: '-0.03em',
            }}
          >
            Sanchiva
          </div>
          <div
            className="sanchiva-logo-tag"
            style={{
              fontSize: Math.max(10, size * 0.22),
              opacity: 0.7,
              fontWeight: 400,
            }}
          >
            Everything that matters
          </div>
        </div>
      </div>
    );
  }

  return Mark;
}
