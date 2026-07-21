import { useEffect, useRef } from 'react';

/**
 * Soft fluid atmosphere inspired by hyperfoundation.org
 * (organic blurred blobs + slow drift — no third-party assets)
 */
export default function AtmosphereBackground({ intensity = 'full' }) {
  const rootRef = useRef(null);

  useEffect(() => {
    const el = rootRef.current;
    if (!el || intensity === 'subtle') return;

    let raf = 0;
    const onMove = (e) => {
      const x = (e.clientX / window.innerWidth - 0.5) * 2;
      const y = (e.clientY / window.innerHeight - 0.5) * 2;
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        el.style.setProperty('--mx', x.toFixed(3));
        el.style.setProperty('--my', y.toFixed(3));
      });
    };

    window.addEventListener('pointermove', onMove, { passive: true });
    return () => {
      window.removeEventListener('pointermove', onMove);
      cancelAnimationFrame(raf);
    };
  }, [intensity]);

  return (
    <div
      ref={rootRef}
      className={`atmosphere-bg atmosphere-bg--${intensity}`}
      aria-hidden
    >
      <div className="atmosphere-base" />
      <div className="atmosphere-blob atmosphere-blob--a" />
      <div className="atmosphere-blob atmosphere-blob--b" />
      <div className="atmosphere-blob atmosphere-blob--c" />
      <div className="atmosphere-blob atmosphere-blob--d" />
      <div className="atmosphere-blob atmosphere-blob--e" />
      <div className="atmosphere-rim" />
      <div className="atmosphere-noise" />
      <div className="atmosphere-vignette" />
    </div>
  );
}
