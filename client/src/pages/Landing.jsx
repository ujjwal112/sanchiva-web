import { Link, Navigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';

const FEATURE_CARDS = [
  {
    title: 'Dashboard',
    text: 'See KPIs, charts, and a clear snapshot of spends, loans, and assets in one calm view so you always know where you stand.',
    accent: 'blue',
    mock: 'dashboard',
  },
  {
    title: 'Daily Expense',
    text: 'Log daily spends with categories, review week and month insights, and export Excel or PDF whenever you need a record.',
    accent: 'purple',
    mock: 'expense',
  },
  {
    title: 'Loans & Credit Cards',
    text: 'Track bank EMIs, credit card spends, and card EMIs with progress summaries so you know what is due and when each loan closes.',
    accent: 'green',
    mock: 'loans',
  },
  {
    title: 'Monetary',
    text: 'Record salary and side income, hold FDs, MFs, crypto and gold in one place, and keep a clear list of money you have given.',
    accent: 'pink',
    mock: 'monetary',
  },
  {
    title: 'Live Currency',
    text: 'Convert any amount between major currencies with free live rates, quick picks, and an INR rates board for USD, EUR, GBP, AED, and more.',
    accent: 'teal',
    mock: 'currency',
  },
  {
    title: 'Live Metals',
    text: 'Check gold, silver, platinum, palladium, and copper with live spots, convert by weight and purity, and compare India city rates or country prices.',
    accent: 'gold',
    mock: 'metals',
  },
  {
    title: 'Events',
    text: 'Plan weddings and life events with a smart wizard, ceremony cards, budgets, todos, and guest lists, all in one place.',
    accent: 'lavender',
    mock: 'events',
  },
  {
    title: 'Secure & personal',
    text: 'Sign in with Google, email, or explore as Guest. Your data stays private; guest demo data resets cleanly when you leave.',
    accent: 'cyan',
    mock: 'secure',
  },
];

function FeatureMock({ type }) {
  if (type === 'dashboard') {
    return (
      <div className="lf-mock lf-mock--dashboard">
        <div className="lf-mock-row">
          <span className="lf-pill lf-pill--blue">This month</span>
          <span className="lf-mock-muted">Overview</span>
        </div>
        <div className="lf-kpi-grid">
          <div className="lf-kpi">
            <span>Spends</span>
            <strong>₹24,800</strong>
          </div>
          <div className="lf-kpi">
            <span>EMIs</span>
            <strong>₹12,400</strong>
          </div>
          <div className="lf-kpi">
            <span>Assets</span>
            <strong>₹4.2L</strong>
          </div>
        </div>
        <div className="lf-bars" aria-hidden>
          <i style={{ height: '42%' }} />
          <i style={{ height: '68%' }} />
          <i style={{ height: '55%' }} />
          <i style={{ height: '80%' }} />
          <i style={{ height: '48%' }} />
        </div>
      </div>
    );
  }
  if (type === 'expense') {
    return (
      <div className="lf-mock lf-mock--expense">
        <div className="lf-mock-label">Add expense</div>
        <div className="lf-field-row">
          <span className="lf-field-prefix">₹</span>
          <span className="lf-field-value">450</span>
          <span className="lf-chip">Food</span>
        </div>
        <div className="lf-mini-list">
          <div>
            <span>Groceries</span>
            <strong>₹1,200</strong>
          </div>
          <div>
            <span>Fuel</span>
            <strong>₹800</strong>
          </div>
          <div>
            <span>Coffee</span>
            <strong>₹180</strong>
          </div>
        </div>
      </div>
    );
  }
  if (type === 'loans') {
    return (
      <div className="lf-mock lf-mock--loans">
        <div className="lf-mock-label">Home loan EMI</div>
        <div className="lf-progress-block">
          <div className="lf-progress-meta">
            <span>Paid</span>
            <strong>62%</strong>
          </div>
          <div className="lf-progress-track">
            <div className="lf-progress-fill" style={{ width: '62%' }} />
          </div>
        </div>
        <div className="lf-mini-list">
          <div>
            <span>Due date</span>
            <strong>5th</strong>
          </div>
          <div>
            <span>Monthly</span>
            <strong>₹18,500</strong>
          </div>
        </div>
      </div>
    );
  }
  if (type === 'monetary') {
    return (
      <div className="lf-mock lf-mock--monetary">
        <div className="lf-mock-label">Amount to track</div>
        <div className="lf-field-row">
          <span className="lf-field-prefix">₹</span>
          <span className="lf-field-value">50,000</span>
          <span className="lf-chip lf-chip--outline">FD</span>
        </div>
        <div className="lf-currency-row">
          <span>Gold</span>
          <span>MF</span>
          <span className="is-active">FD</span>
          <span>Stocks</span>
        </div>
      </div>
    );
  }
  if (type === 'currency') {
    return (
      <div className="lf-mock lf-mock--currency">
        <div className="lf-mock-row">
          <span className="lf-mock-label" style={{ margin: 0 }}>
            Convert
          </span>
          <span className="lf-pill lf-pill--teal">Live</span>
        </div>
        <div className="lf-field-row">
          <span className="lf-field-prefix">₹</span>
          <span className="lf-field-value">1,000</span>
          <span className="lf-chip">INR</span>
        </div>
        <div className="lf-fx-result">
          <span className="lf-mock-muted">→ USD</span>
          <strong>$11.62</strong>
        </div>
        <div className="lf-mini-list">
          <div>
            <span>1 USD</span>
            <strong>₹86.05</strong>
          </div>
          <div>
            <span>1 EUR</span>
            <strong>₹93.40</strong>
          </div>
        </div>
      </div>
    );
  }
  if (type === 'metals') {
    return (
      <div className="lf-mock lf-mock--metals">
        <div className="lf-mock-row">
          <span className="lf-mock-label" style={{ margin: 0 }}>
            Gold · 22K
          </span>
          <span className="lf-pill lf-pill--gold">Live</span>
        </div>
        <div className="lf-field-row">
          <span className="lf-field-value">10 g</span>
          <span className="lf-chip lf-chip--outline">Mumbai</span>
        </div>
        <div className="lf-fx-result">
          <span className="lf-mock-muted">Estimated</span>
          <strong>₹1,15,420</strong>
        </div>
        <div className="lf-mini-list">
          <div>
            <span>22K / g</span>
            <strong>₹11,542</strong>
          </div>
          <div>
            <span>Silver / g</span>
            <strong>₹181</strong>
          </div>
        </div>
      </div>
    );
  }
  if (type === 'events') {
    return (
      <div className="lf-mock lf-mock--events">
        <div className="lf-mock-label">Wedding plan</div>
        <div className="lf-event-line">
          <span className="lf-icon-box">💍</span>
          <div>
            <strong>Mehendi</strong>
            <span>12 guests · budget set</span>
          </div>
        </div>
        <div className="lf-event-line">
          <span className="lf-icon-box">🎉</span>
          <div>
            <strong>Reception</strong>
            <span>Todos · 4 remaining</span>
          </div>
        </div>
      </div>
    );
  }
  return (
    <div className="lf-mock lf-mock--secure">
      <div className="lf-mock-label">Sign in</div>
      <div className="lf-auth-btns">
        <span className="lf-auth-btn">G · Google</span>
        <span className="lf-auth-btn lf-auth-btn--ghost">Email</span>
      </div>
      <div className="lf-secure-note">
        <span className="lf-lock">🔒</span>
        <span>Private sessions · guest demo resets</span>
      </div>
    </div>
  );
}

function HeroMock() {
  return (
    <div className="landing-hero-stack">
      {/* Vault card shown in front by default */}
      <div
        className="landing-hero-card landing-hero-card--back"
        tabIndex={0}
        role="group"
        aria-label="Your vault preview"
      >
        <div className="landing-hero-card-brand">
          <Logo size={22} />
          <span>Sanchiva</span>
        </div>
        <div className="landing-hero-profile">
          <div className="landing-hero-avatar">U</div>
          <div>
            <strong>Your vault</strong>
            <span>Personal finance</span>
          </div>
        </div>
        <ul className="landing-hero-meta">
          <li>
            <span>📊</span> Live dashboard
          </li>
          <li>
            <span>₹</span> Daily tracking
          </li>
          <li>
            <span>✦</span> Events &amp; EMIs
          </li>
        </ul>
      </div>
      {/* Peeks behind; hover to bring fully forward */}
      <div
        className="landing-hero-card landing-hero-card--front"
        tabIndex={0}
        role="group"
        aria-label="Money at a glance. Hover to bring this card forward."
      >
        <h4>Money at a glance</h4>
        <div className="landing-hero-methods">
          <div>
            <span>◈</span> Dashboard
          </div>
          <div>
            <span>₹</span> Expenses
          </div>
          <div>
            <span>◫</span> Loans
          </div>
          <div>
            <span>◎</span> Assets
          </div>
          <div>
            <span>✦</span> Events
          </div>
        </div>
      </div>
    </div>
  );
}

function SplitMock({ variant }) {
  if (variant === 'complete') {
    return (
      <div className="landing-split-visual landing-split-visual--lavender" aria-hidden>
        <div className="landing-split-card">
          <h4>All set</h4>
          <div className="landing-split-lines">
            <div>
              <span className="lf-icon-box">📅</span>
              <div>
                <strong>Month tracked</strong>
                <span>Daily expenses logged</span>
              </div>
            </div>
            <div>
              <span className="lf-icon-box">💳</span>
              <div>
                <strong>EMIs on track</strong>
                <span>₹12,400 paid this month</span>
              </div>
            </div>
            <div>
              <span className="lf-icon-box">👤</span>
              <div>
                <strong>Your account</strong>
                <span>Secure &amp; private</span>
              </div>
            </div>
            <div>
              <span className="lf-icon-box lf-icon-box--pink">₹</span>
              <div>
                <strong>Export ready</strong>
                <span>Excel · PDF anytime</span>
              </div>
            </div>
            <div>
              <span className="lf-icon-box">◎</span>
              <div>
                <strong>Display currency</strong>
                <span>₹ $ € £ · pick in profile</span>
              </div>
            </div>
          </div>
          <p className="landing-split-footnote">Your data stays in your vault.</p>
        </div>
      </div>
    );
  }
  return (
    <div className="landing-split-visual landing-split-visual--blue" aria-hidden>
      <div className="landing-split-card">
        <div className="landing-hero-card-brand">
          <Logo size={22} />
          <span>Sanchiva</span>
        </div>
        <div className="landing-hero-profile">
          <div className="landing-hero-avatar">S</div>
          <div>
            <strong>Monthly plan</strong>
            <span>Budget · Loans · Events</span>
          </div>
        </div>
        <ul className="landing-hero-meta">
          <li>
            <span>⏱</span> Live totals
          </li>
          <li>
            <span>📈</span> Charts &amp; exports
          </li>
          <li>
            <span>🔒</span> Private by default
          </li>
        </ul>
      </div>
      <div className="landing-split-card landing-split-card--overlay">
        <h4>What you track</h4>
        <div className="landing-hero-methods">
          <div>
            <span>₹</span> Spends
          </div>
          <div>
            <span>◫</span> EMIs
          </div>
          <div>
            <span>◎</span> Income
          </div>
          <div>
            <span>✦</span> Events
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Landing() {
  const { isAuthenticated, loading } = useAuth();

  if (!loading && isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="landing-page">
      <header className="landing-header">
        <Link to="/" className="landing-brand" aria-label="Sanchiva home">
          <Logo size={36} />
          <div className="landing-brand-text">
            <strong>Sanchiva</strong>
            <span>Everything that matters</span>
          </div>
        </Link>
        <div className="landing-header-actions">
          <Link to="/login" className="btn btn-ghost landing-login-btn">
            Login
          </Link>
          <Link to="/signup" className="btn btn-primary landing-login-btn landing-cta">
            Get started
          </Link>
        </div>
      </header>

      <main className="landing-main">
        {/* Hero: first_card style, mock left, copy right */}
        <section className="landing-hero">
          <div className="landing-hero-visual">
            <HeroMock />
          </div>
          <div className="landing-hero-copy">
            <p className="landing-eyebrow">Personal finance · Life events</p>
            <h1>
              Everything that matters,
              <br />
              one place
            </h1>
            <p className="landing-lead">
              Sanchiva helps you collect, track, and protect what counts: daily expenses, loans,
              credit cards, income, assets, money lent, and big life events in a calm modern
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
        </section>

        {/* Features */}
        <section id="features" className="landing-features" aria-label="Features">
          <div className="landing-features-intro">
            <h2>One app for money and moments</h2>
            <p>
              Whether you track daily spends, check live rates, or plan a wedding, tailor every
              module to how you live: clear tools, one white-and-simple experience.
            </p>
          </div>

          <div className="landing-feature-grid">
            {FEATURE_CARDS.map((f) => (
              <article key={f.title} className={`landing-feature-card accent-${f.accent}`}>
                <div className="landing-feature-card-copy">
                  <h3>{f.title}</h3>
                  <p>{f.text}</p>
                </div>
                <div className="landing-feature-card-stage">
                  <div className="landing-feature-blob" aria-hidden />
                  <FeatureMock type={f.mock} />
                </div>
              </article>
            ))}
          </div>
        </section>

        {/* Split: 3rd_card style */}
        <section className="landing-split landing-split--reverse">
          <div className="landing-split-copy">
            <h2>Built as your personal vault</h2>
            <p>
              Collection, accumulation, preservation: Sanchiva gathers wealth and values over time.
              Charts and exports when you need insight, event planning when life gets bigger than a
              spreadsheet.
            </p>
            <ul className="landing-bullets">
              <li>Per-user data with secure JWT sessions</li>
              <li>Google sign-in or try instantly as Guest</li>
              <li>Excel &amp; PDF downloads across modules</li>
              <li>Event wizard with ceremonies, todos, and guests</li>
              <li>Display currency from your profile (₹, $, €, £, and more)</li>
            </ul>
          </div>
          <SplitMock variant="complete" />
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
