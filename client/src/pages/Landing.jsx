import { useEffect, useRef, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';

const FEATURES = [
  {
    icon: '◈',
    title: 'Dashboard',
    tagline: 'Your money at a glance',
    text: 'See KPIs, charts, and a clear snapshot of spends, loans, and assets in one calm view—so you always know where you stand without opening five apps.',
    points: [
      'Live totals for spends, EMIs, income & assets',
      'Week and month charts that stay readable',
      'Quick jump into any module from one home',
    ],
  },
  {
    icon: '₹',
    title: 'Daily Expense',
    tagline: 'Every rupee, tracked gently',
    text: 'Log daily spends with categories, review week and month insights, and export Excel or PDF when you need a record—perfect for households and personal budgets.',
    points: [
      'Fast entry with categories you actually use',
      'Week / month summaries and pie breakdowns',
      'Excel & PDF export whenever you need it',
    ],
  },
  {
    icon: '◫',
    title: 'Loans & Credit Cards',
    tagline: 'EMIs under control',
    text: 'Track bank EMIs, credit card spends, and card EMIs with progress summaries—know what is due, what is left, and when each loan closes.',
    points: [
      'Bank loans with EMI date and close year',
      'Credit card spends by type and card',
      'Card EMI schedules with start / end periods',
    ],
  },
  {
    icon: '◎',
    title: 'Monetary',
    tagline: 'Income, assets & money lent',
    text: 'Record salary and side income, hold your FDs, MFs, crypto and gold in one place, and keep a clear list of money you have given to people.',
    points: [
      'Monthly income sources with balances',
      'Assets across FD, RD, stocks, gold & more',
      'Money given with dates and notes',
    ],
  },
  {
    icon: '✦',
    title: 'Events',
    tagline: 'Weddings & celebrations, planned',
    text: 'Plan weddings and life events with a smart wizard, ceremony cards, budgets, todos, and guest lists—so big days stay organised instead of living in chats and sheets.',
    points: [
      'Wizard for wedding, birthday, corporate & more',
      'Ceremony cards with dates and blessings',
      'Todos, budgets, guests and exports',
    ],
  },
  {
    icon: '🔒',
    title: 'Secure & personal',
    tagline: 'Your vault, your rules',
    text: 'Sign in with Google, email, or explore as Guest with sample data. Your account stays private; guest extras reset when you leave so demos stay clean.',
    points: [
      'Google, email/password, or Guest login',
      'Per-user data with secure sessions',
      'Guest demo data resets on logout',
    ],
  },
];

function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n));
}

/**
 * Features: sticky vertical stack — scroll down and each card rolls
 * from front to back with smooth fade/scale (no horizontal scroll).
 */
export default function Landing() {
  const { isAuthenticated, loading } = useAuth();
  const pinRef = useRef(null);
  const [progress, setProgress] = useState(0);
  const [activeIndex, setActiveIndex] = useState(0);
  const [reduceMotion, setReduceMotion] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const apply = () => setReduceMotion(mq.matches);
    apply();
    mq.addEventListener?.('change', apply);
    return () => mq.removeEventListener?.('change', apply);
  }, []);

  useEffect(() => {
    if (reduceMotion) return undefined;
    const pin = pinRef.current;
    if (!pin) return undefined;

    let raf = 0;
    const measure = () => {
      const rect = pin.getBoundingClientRect();
      const scrollable = Math.max(1, pin.offsetHeight - window.innerHeight);
      const p = clamp(-rect.top / scrollable, 0, 1);
      setProgress(p);
      setActiveIndex(Math.min(FEATURES.length - 1, Math.floor(p * FEATURES.length * 0.999)));
    };

    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(measure);
    };

    measure();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
    };
  }, [reduceMotion]);

  if (!loading && isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  // ~1 viewport of scroll “dwell” per card after the first sticky frame
  const pinHeightVh = 100 + FEATURES.length * 70;

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
      </main>

      {/* Full-bleed vertical stack theater */}
      <section
        id="features"
        ref={pinRef}
        className={`landing-features-stack${reduceMotion ? ' is-static' : ''}`}
        style={reduceMotion ? undefined : { height: `${pinHeightVh}vh` }}
        aria-label="Features"
      >
        <div className="landing-features-sticky">
          <div className="landing-features-sticky-inner">
            <div className="landing-section-head landing-features-head">
              <p className="landing-eyebrow">What you can do</p>
              <div className="landing-features-head-row">
                <div>
                  <h2>One app for money and moments</h2>
                  <p className="muted">
                    Scroll down — each feature comes to the front, then rolls behind with a smooth
                    fade as the next one appears.
                  </p>
                </div>
                <div className="landing-features-counter" aria-live="polite">
                  <span className="landing-features-counter-num">
                    {String(activeIndex + 1).padStart(2, '0')}
                  </span>
                  <span className="landing-features-counter-sep">/</span>
                  <span className="landing-features-counter-total">
                    {String(FEATURES.length).padStart(2, '0')}
                  </span>
                </div>
              </div>
            </div>

            <div className="landing-features-stage">
              {FEATURES.map((f, i) => {
                // Continuous “front” index along the scrub (0 … n-1)
                const front = progress * (FEATURES.length - 1);
                const dist = i - front; // 0 = current front; >0 waiting; <0 already passed behind
                const abs = Math.abs(dist);

                // Front card: scale 1, opacity 1; behind: shrink + fade + push back
                let scale = 1 - Math.min(abs, 2.2) * 0.06;
                let opacity = 1 - Math.min(Math.max(-dist, 0), 1.15) * 0.85;
                let y = dist * 18;
                let blur = Math.min(Math.max(-dist, 0), 1) * 6;
                let z = 100 - Math.round(abs * 10);
                // Cards still ahead sit slightly behind and dimmer
                if (dist > 0.05) {
                  scale = 0.94 - Math.min(dist, 1.5) * 0.03;
                  opacity = 0.35 + Math.max(0, 1 - dist) * 0.35;
                  y = 28 + dist * 12;
                  blur = 2 + dist * 2;
                  z = 40 - Math.round(dist * 8);
                }
                // Passed cards recede to the back
                if (dist < -0.05) {
                  scale = 0.92 + dist * 0.04;
                  opacity = Math.max(0, 1 + dist * 1.15);
                  y = dist * 22;
                  blur = Math.min(8, -dist * 7);
                  z = 20 + Math.round(dist * 5);
                }

                if (reduceMotion) {
                  scale = 1;
                  opacity = 1;
                  y = 0;
                  blur = 0;
                  z = FEATURES.length - i;
                }

                const isFront = i === activeIndex && !reduceMotion;

                return (
                  <article
                    key={f.title}
                    className={`landing-feature-card landing-feature-card--stack${isFront ? ' is-front' : ''}`}
                    style={{
                      zIndex: z,
                      opacity,
                      transform: `translate3d(-50%, calc(-50% + ${y}px), 0) scale(${scale})`,
                      filter: blur > 0.2 ? `blur(${blur}px)` : 'none',
                      pointerEvents: isFront || reduceMotion ? 'auto' : 'none',
                    }}
                    aria-hidden={!isFront && !reduceMotion}
                  >
                    <div className="landing-feature-card-inner">
                      <div className="landing-feature-card-top">
                        <span className="landing-feature-icon" aria-hidden>
                          {f.icon}
                        </span>
                        <span className="landing-feature-index" aria-hidden>
                          {String(i + 1).padStart(2, '0')}
                        </span>
                      </div>
                      <p className="landing-feature-tagline">{f.tagline}</p>
                      <h3>{f.title}</h3>
                      <p className="landing-feature-text muted">{f.text}</p>
                      <ul className="landing-feature-points">
                        {f.points.map((pt) => (
                          <li key={pt}>{pt}</li>
                        ))}
                      </ul>
                    </div>
                  </article>
                );
              })}
            </div>

            <div className="landing-features-progress" aria-hidden>
              <div
                className="landing-features-progress-bar"
                style={{ transform: `scaleX(${Math.max(0.06, progress)})` }}
              />
            </div>
          </div>
        </div>
      </section>

      <main className="landing-main landing-main--after-features">
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
