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
    text: 'Google or Guest login. Your data stays private to your account — guest data wipes on logout.',
  },
];

export default function Landing() {
  const { isAuthenticated, loading } = useAuth();

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
        <Link to="/login" className="btn btn-primary landing-login-btn">
          Login
        </Link>
      </header>

      <main className="landing-main">
        <section className="landing-hero card">
          <div className="landing-hero-copy">
            <p className="landing-eyebrow">Personal finance · Life events</p>
            <h1>
              Everything that matters
              <span className="landing-hero-accent"> — one place.</span>
            </h1>
            <p className="landing-lead muted">
              Sanchiva helps you collect, track, and protect what counts: daily expenses, loans,
              credit cards, income, assets, money lent, and big life events — all in a calm modern
              workspace.
            </p>
            <div className="landing-hero-actions">
              <Link to="/login" className="btn btn-primary landing-cta">
                Get started — Login
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

        <section id="features" className="landing-section">
          <div className="landing-section-head">
            <p className="landing-eyebrow">What you can do</p>
            <h2>One app for money and moments</h2>
            <p className="muted">
              Built so nothing important slips through — from this month’s groceries to your wedding
              guest list.
            </p>
          </div>
          <div className="landing-features-grid">
            {FEATURES.map((f) => (
              <article key={f.title} className="card landing-feature-card">
                <span className="landing-feature-icon" aria-hidden>
                  {f.icon}
                </span>
                <h3>{f.title}</h3>
                <p className="muted">{f.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="landing-section">
          <div className="card landing-about-block">
            <div>
              <p className="landing-eyebrow">About Sanchiva</p>
              <h2>Collection · Accumulation · Preservation</h2>
              <p className="muted">
                The name <strong>Sanchiva</strong> echoes collection, accumulation, preservation, and
                savings — wealth and values gathered over time. The product is designed as a personal
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
              <p className="muted">Sign in securely and open your dashboard in seconds.</p>
              <Link to="/login" className="btn btn-primary">
                Login to Sanchiva
              </Link>
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
          <Link to="/login" className="landing-footer-login">
            Login
          </Link>
        </div>
      </footer>
    </div>
  );
}
