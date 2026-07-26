/**
 * Sanchiva logo — enhanced ribbon “S” mark (transparent background).
 * Primary: high-res PNG with plate removed + color boost.
 * Fallback: crisp SVG mark.
 */
export const LOGO_SRC = '/sanchiva-logo.png';
export const LOGO_SVG = '/sanchiva-logo.svg';

export default function Logo({
  size = 40,
  className = '',
  title = 'Sanchiva',
  variant = 'mark', // mark | full
  showWordmark = false,
}) {
  const markSize = size;

  const Mark = (
    <span
      className={`sanchiva-logo-mark-wrap ${className}`.trim()}
      style={{
        width: markSize,
        height: markSize,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        lineHeight: 0,
      }}
      role="img"
      aria-label={title}
      title={title}
    >
      <img
        src={LOGO_SRC}
        alt=""
        width={markSize}
        height={markSize}
        className="sanchiva-logo-mark"
        style={{
          width: markSize,
          height: markSize,
          objectFit: 'contain',
          display: 'block',
          background: 'transparent',
        }}
        decoding="async"
        onError={(e) => {
          if (!e.currentTarget.dataset.fallback) {
            e.currentTarget.dataset.fallback = '1';
            e.currentTarget.src = LOGO_SVG;
          }
        }}
      />
    </span>
  );

  if (variant === 'full' || showWordmark) {
    return (
      <div
        className={`sanchiva-logo-full ${className}`.trim()}
        style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.22 }}
      >
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
