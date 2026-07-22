import { useEffect, useRef, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';

const FEATURES = [
  {
    icon: '◈',
    title: 'Dashboard',
    text: 'See KPIs, charts, and a clear snapshot of spends, loans, and assets in one view.',
  },
  {
    icon: '₹',
    title: 'Daily Expense',
    text: 'Log daily spends with categories, week and month views, plus Excel and PDF export.',
  },
  {
    icon: '◫',
    title: 'Loans & Credit Cards',
    text: 'Track bank EMIs, credit card spends, and card EMIs with progress summaries.',
  },
  {
    icon: '◎',
    title: 'Monetary',
    text: 'Record income, assets (FD, MF, crypto…), and money you have lent to people.',
  },
  {
    icon: '✦',
    title: 'Events',
    text: 'Plan weddings and celebrations with smart checklists, budgets, ceremony cards, and guests.',
  },
  {
    icon: '🔒',
    title: 'Secure & personal',
    text: 'Google or Guest login. Guest includes sample data you can explore; your adds reset on logout.',
  },
];

export default function Landing() {
  const { isAuthenticated, loading } = useAuth();
  const featuresRef = useRef(null);
  const trackRef = useRef(null);
  const [sectionVisible, setSectionVisible] = useState(false);
  const [visibleCards, setVisibleCards] = useState(() => new Set());
  const [scrollProgress, setScrollProgress] = useState(0);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(true);
  const userPausedRef = useRef(false);

  // Reveal features section when it enters the viewport
  useEffect(() => {
    const el = featuresRef.current;
    if (!el) return undefined;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) setSectionVisible(true);
      },
      { threshold: 0.18, rootMargin: '0px 0px -8% 0px' }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // Stagger card reveal + track scroll progress for edge fades / bar
  useEffect(() => {
    const track = trackRef.current;
    if (!track) return undefined;

    const updateScrollMeta = () => {
      const max = track.scrollWidth - track.clientWidth;
      const left = track.scrollLeft;
      setScrollProgress(max > 0 ? left / max : 0);
      setCanScrollLeft(left > 4);
      setCanScrollRight(left < max - 4);
    };

    updateScrollMeta();
    track.addEventListener('scroll', updateScrollMeta, { passive: true });
    window.addEventListener('resize', updateScrollMeta);

    const cards = track.querySelectorAll('.landing-feature-card');
    const cardIo = new IntersectionObserver(
      (entries) => {
        setVisibleCards((prev) => {
          const next = new Set(prev);
          for (const entry of entries) {
            const idx = entry.target.getAttribute('data-feature-index');
            if (entry.isIntersecting && idx != null) next.add(idx);
          }
          return next;
        });
      },
      { root: track, threshold: 0.28, rootMargin: '0px 20% 0px 8%' }
    );
    cards.forEach((c) => cardIo.observe(c));

    // Seed first cards so the rail isn’t empty when the section appears
    if (sectionVisible) {
      setVisibleCards((prev) => {
        const next = new Set(prev);
        next.add('0');
        next.add('1');
        next.add('2');
        return next;
      });
    }

    // Gentle auto-scroll while section is in view; pauses on user interaction
    let raf = 0;
    let last = performance.now();
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const tick = (now) => {
      const dt = Math.min(32, now - last);
      last = now;
      if (!userPausedRef.current && sectionVisible && !reduceMotion) {
        const max = track.scrollWidth - track.clientWidth;
        if (max > 0) {
          let next = track.scrollLeft + dt * 0.03;
          if (next >= max - 1) next = 0;
          track.scrollLeft = next;
        }
      }
      raf = requestAnimationFrame(tick);
    };
    if (!reduceMotion) raf = requestAnimationFrame(tick);

    let resumeTimer = 0;
    const pause = () => {
      userPausedRef.current = true;
      window.clearTimeout(resumeTimer);
    };
    const resume = () => {
      window.clearTimeout(resumeTimer);
      resumeTimer = window.setTimeout(() => {
        userPausedRef.current = false;
      }, 2400);
    };

    // Vertical wheel → horizontal scroll when over the rail
    const onWheel = (e) => {
      if (track.scrollWidth <= track.clientWidth) return;
      if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) {
        e.preventDefault();
        track.scrollLeft += e.deltaY;
      }
      pause();
      resume();
    };

    track.addEventListener('pointerdown', pause);
    track.addEventListener('touchstart', pause, { passive: true });
    track.addEventListener('pointerleave', resume);
    track.addEventListener('wheel', onWheel, { passive: false });

    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(resumeTimer);
      track.removeEventListener('scroll', updateScrollMeta);
      window.removeEventListener('resize', updateScrollMeta);
      track.removeEventListener('pointerdown', pause);
      track.removeEventListener('touchstart', pause);
      track.removeEventListener('pointerleave', resume);
      track.removeEventListener('wheel', onWheel);
      cardIo.disconnect();
    };
  }, [sectionVisible]);

  const scrollFeaturesBy = (dir) => {
    const track = trackRef.current;
    if (!track) return;
    userPausedRef.current = true;
    const amount = Math.min(340, track.clientWidth * 0.78);
    track.scrollBy({ left: dir * amount, behavior: 'smooth' });
    window.setTimeout(() => {
      userPausedRef.current = false;
    }, 2600);
  };

  if (!loading && isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="landing-page">
      <header className="landing-header">
        <Link to="/" className="landing-brand" aria-label="Sanchiva home">
          <Logo size={40} />
          <div className="landing-brand-text">
            <strong>Sanchiva</strong>
            <span className="muted">Everything that matters</span>
          </div>
        </Link>
        <div className="landing-header-actions">
          <Link to="/login" className="btn btn-ghost landing-login-btn">
            Login
          </Link>
          <Link to="/signup" className="btn btn-primary landing-login-btn">
            Sign up
          </Link>
        </div>
      </header>

      <main className="landing-main">
        <section className="landing-hero card">
          <div className="landing-hero-copy">
            <p className="landing-eyebrow">Personal finance · Life events</p>
            <h1>
              Everything that matters
              <span className="landing-hero-accent">, one place.</span>
            </h1>
            <p className="landing-lead muted">
              Sanchiva helps you collect, track, and protect what counts: daily expenses, loans,
              credit cards, income, assets, money lent, and big life events, all in a calm modern
              workspace.
            </p>
            <div className="landing-hero-actions">
              <Link to="/signup" className="btn btn-primary landing-cta">
                Get started
              </Link>
              <a href="#features" className="btn btn-ghost landing-cta-secondary">
                Explore features
              </a>
            </div>
          </div>
          <div className="landing-hero-visual" aria-hidden>
            <Logo size={120} className="landing-hero-logo" />
            <div className="landing-hero-glow" />
          </div>
        </section>

        <section
          id="features"
          ref={featuresRef}
          className={`landing-section landing-features-section${sectionVisible ? ' is-visible' : ''}`}
        >
          <div className="landing-section-head landing-features-head">
            <p className="landing-eyebrow">What you can do</p>
            <div className="landing-features-head-row">
              <div>
                <h2>One app for money and moments</h2>
                <p className="muted">
                  Scroll the cards — built so nothing important slips through, from groceries to your
                  wedding guest list.
                </p>
              </div>
              <div className="landing-features-nav" aria-hidden={false}>
                <button
                  type="button"
                  className="landing-features-nav-btn"
                  onClick={() => scrollFeaturesBy(-1)}
                  disabled={!canScrollLeft}
                  aria-label="Previous features"
                >
                  ‹
                </button>
                <button
                  type="button"
                  className="landing-features-nav-btn"
                  onClick={() => scrollFeaturesBy(1)}
                  disabled={!canScrollRight}
                  aria-label="Next features"
                >
                  ›
                </button>
              </div>
            </div>
          </div>

          <div className="landing-features-rail">
            <div
              className="landing-features-fade landing-features-fade--left"
              data-active={canScrollLeft ? 'true' : 'false'}
              aria-hidden
            />
            <div
              className="landing-features-fade landing-features-fade--right"
              data-active={canScrollRight ? 'true' : 'false'}
              aria-hidden
            />
            <div
              ref={trackRef}
              className="landing-features-track"
              tabIndex={0}
              role="region"
              aria-label="Feature cards — scroll horizontally"
            >
              {FEATURES.map((f, i) => (
                <article
                  key={f.title}
                  data-feature-index={String(i)}
                  className={`card landing-feature-card${visibleCards.has(String(i)) ? ' is-inview' : ''}`}
                  style={{ '--feature-delay': `${i * 80}ms` }}
                >
                  <span className="landing-feature-icon" aria-hidden>
                    {f.icon}
                  </span>
                  <h3>{f.title}</h3>
                  <p className="muted">{f.text}</p>
                </article>
              ))}
            </div>
          </div>

          <div className="landing-features-progress" aria-hidden>
            <div
              className="landing-features-progress-bar"
              style={{ transform: `scaleX(${Math.max(0.08, scrollProgress || 0.08)})` }}
            />
          </div>
        </section>

        <section className="landing-section">
          <div className="card landing-about-block">
            <div>
              <p className="landing-eyebrow">About Sanchiva</p>
              <h2>Collection · Accumulation · Preservation</h2>
              <p className="muted">
                The name <strong>Sanchiva</strong> echoes collection, accumulation, preservation, and
                savings: wealth and values gathered over time. The product is designed as a personal
                vault: charts and exports when you need insight, and event planning when life gets
                bigger than a spreadsheet.
              </p>
              <ul className="landing-bullets">
                <li>Per-user data with secure JWT sessions</li>
                <li>Google sign-in or try instantly as Guest</li>
                <li>Excel &amp; PDF downloads across modules</li>
                <li>Event wizard with ceremony dates, todos, and guests</li>
              </ul>
            </div>
            <div className="landing-cta-panel">
              <Logo size={56} />
              <h3>Ready to start?</h3>
              <p className="muted">Create an account or log in with Google or email and password.</p>
              <div className="landing-cta-panel-actions">
                <Link to="/signup" className="btn btn-primary">
                  Sign up
                </Link>
                <Link to="/login" className="btn btn-ghost">
                  Login
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="landing-footer">
        <div className="landing-footer-inner">
          <div className="landing-footer-brand">
            <Logo size={28} />
            <span>Sanchiva</span>
          </div>
          <p className="muted">
            © {new Date().getFullYear()} Sanchiva. Developed by <strong>Ujjwal Gupta</strong>. All
            rights reserved.
          </p>
          <div className="landing-footer-links">
            <Link to="/signup" className="landing-footer-login">
              Sign up
            </Link>
            <Link to="/login" className="landing-footer-login">
              Login
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
