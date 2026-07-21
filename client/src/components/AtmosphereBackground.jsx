import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';

/**
 * Letter design atmosphere — soft gallery wall washes on light pages,
 * vault-ink stage on landing / auth.
 */
export default function AtmosphereBackground() {
  const { pathname } = useLocation();
  const rootRef = useRef(null);
  const dark =
    pathname === '/' ||
    pathname === '/login' ||
    pathname === '/signup' ||
    pathname.startsWith('/auth');

  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;

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
  }, []);

  return (
    <div
      ref={rootRef}
      className={`atmosphere-bg ${dark ? 'atmosphere-bg--dark' : 'atmosphere-bg--light'}`}
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
