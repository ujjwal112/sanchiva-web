import Logo from '../components/Logo';

export default function About() {
  return (
    <div className="about-page">
      <div className="card about-hero">
        <div className="about-hero__logo-wrap">
          <Logo size={88} className="about-hero__logo" />
        </div>
        <div>
          <h3 className="about-hero__name">Sanchiva</h3>
          <p className="about-hero__motto">“Everything that matters — one place.”</p>
          <p className="muted about-hero__tag">
            Collection · Accumulation · Preservation · Savings · Wealth gathered over time
          </p>
        </div>
      </div>

      <div className="grid grid-2 about-grid">
        <div className="card about-block">
          <h3>About the app</h3>
          <p>
            <strong>Sanchiva</strong> is your personal finance and life-value companion. It helps you track daily
            spends, loans and credit cards, income and assets, money lent to people, and even life events —
            so nothing important slips through the cracks.
          </p>
          <p>
            From week-wise expense pies to EMI progress, asset mix, and event budgets with guest lists,
            Sanchiva is built to collect and organize everything valuable in your financial life in one calm,
            modern workspace.
          </p>
        </div>

        <div className="card about-block">
          <h3>What you can do</h3>
          <ul className="about-list">
            <li>
              <strong>Dashboard</strong> — charts and KPIs across your money flow
            </li>
            <li>
              <strong>Daily Expense</strong> — entry, week/month views, Excel &amp; PDF exports
            </li>
            <li>
              <strong>Loans / Credit Card</strong> — EMIs, progress, card spends
            </li>
            <li>
              <strong>Monetary</strong> — income, assets, money lent
            </li>
            <li>
              <strong>Events</strong> — plan weddings, birthdays &amp; more with smart checklists
            </li>
          </ul>
        </div>
      </div>

      <div className="card about-creator">
        <div className="about-creator__inner">
          <Logo size={56} className="about-creator__logo" />
          <div>
            <p className="muted about-creator__label">Developed by</p>
            <h3>Ujjwal Gupta</h3>
            <p className="muted">
              Designed and built to help people collect, preserve, and grow what matters — one place at a time.
            </p>
          </div>
        </div>
        <div className="about-copyright">
          <p>© {new Date().getFullYear()} Sanchiva. All rights reserved.</p>
          <p className="muted">
            Sanchiva and its logo are the intellectual property of Ujjwal Gupta. Unauthorized copying,
            distribution, or modification is prohibited.
          </p>
        </div>
      </div>
    </div>
  );
}
