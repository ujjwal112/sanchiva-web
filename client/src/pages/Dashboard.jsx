import { useEffect, useState } from 'react';
import { api, formatCurrency, MONTHS } from '../api';
import { PieChart, BarChart, LineChart, MultiBarChart, categoryChartData } from '../components/Charts';

export default function Dashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get('/dashboard')
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);

  if (error) {
    return (
      <div className="card">
        <h3>Could not load dashboard</h3>
        <p className="muted">{error}</p>
        <p className="muted" style={{ marginTop: '0.5rem' }}>
          Ensure the API and PostgreSQL are running.
        </p>
      </div>
    );
  }

  if (!data) return <div className="card">Loading dashboard…</div>;

  const k = data.kpis;
  const monthPie = categoryChartData(data.monthExpenseCard?.byCategory);
  const bankLabels = (data.loanBankCard?.banks || []).map((b) => b.bank);
  const bankValues = (data.loanBankCard?.banks || []).map((b) => b.totalEmi);
  const closure = data.loanClosureYearCard || [];
  const assetPie = categoryChartData(data.assetsByType);
  const givenPie = categoryChartData(data.moneyGivenByPerson);

  return (
    <div className="stack-sm" style={{ gap: '1.1rem', display: 'flex', flexDirection: 'column' }}>
      <div className="grid grid-4 stagger">
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>This month spent</h3>
              <p className="muted">
                {MONTHS[(data.month || 1) - 1]} {data.year}
              </p>
            </div>
            <div className="kpi-icon">₹</div>
          </div>
          <div className="metric">{formatCurrency(k.monthExpenseTotal)}</div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Income</h3>
              <p className="muted">Salary & sources</p>
            </div>
            <div className="kpi-icon">↑</div>
          </div>
          <div className="metric">{formatCurrency(k.monthIncome)}</div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Balance</h3>
              <p className="muted">Income − spends</p>
            </div>
            <div className="kpi-icon">◎</div>
          </div>
          <div className="metric">{formatCurrency(k.monthBalance)}</div>
        </div>
        <div className="card">
          <div className="flex-between">
            <div>
              <h3>Monthly EMI</h3>
              <p className="muted">
                {k.activeLoans} active · {k.closedLoans} closed
              </p>
            </div>
            <div className="kpi-icon">◫</div>
          </div>
          <div className="metric">{formatCurrency(k.monthlyEmi)}</div>
        </div>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3>Month-wise expense · category pie</h3>
          <p className="muted">
            Total {formatCurrency(data.monthExpenseCard?.total)} in {MONTHS[(data.month || 1) - 1]}
          </p>
          <PieChart labels={monthPie.labels} values={monthPie.values} doughnut />
        </div>
        <div className="card">
          <h3>Expense trend</h3>
          <p className="muted">Last ~6 months</p>
          <LineChart
            labels={(data.expenseTrend || []).map((t) => t.label)}
            values={(data.expenseTrend || []).map((t) => t.total)}
          />
        </div>
      </div>

      <div className="grid grid-3">
        <div className="card">
          <h3>Loans this month</h3>
          <p className="muted">Total obligation vs deducted vs remaining</p>
          <div className="stat-row">
            <span>Total loan amount</span>
            <strong>{formatCurrency(data.loanMonthCard?.totalLoanAmount)}</strong>
          </div>
          <div className="stat-row">
            <span>Deducted this month</span>
            <strong>{formatCurrency(data.loanMonthCard?.deductedThisMonth)}</strong>
          </div>
          <div className="stat-row">
            <span>Remaining to deduct</span>
            <strong>{formatCurrency(data.loanMonthCard?.remainingToDeduct)}</strong>
          </div>
          <PieChart
            labels={['Deducted this month', 'Remaining']}
            values={[
              data.loanMonthCard?.deductedThisMonth || 0,
              data.loanMonthCard?.remainingToDeduct || 0,
            ]}
            doughnut
          />
        </div>

        <div className="card">
          <h3>EMI by deduction bank</h3>
          <p className="muted">
            Active {data.loanBankCard?.totalActiveLoans} · Monthly EMI{' '}
            {formatCurrency(data.loanBankCard?.totalMonthlyEmi)} · Closed{' '}
            {data.loanBankCard?.closedLoansCount}
          </p>
          <BarChart labels={bankLabels} values={bankValues} label="EMI / bank" />
        </div>

        <div className="card">
          <h3>Loan closure by year</h3>
          <p className="muted">Closing schedule overview</p>
          <MultiBarChart
            labels={closure.map((c) => String(c.year))}
            datasets={[
              { label: 'Closing', values: closure.map((c) => c.closingCount) },
              { label: 'Closed', values: closure.map((c) => c.closedCount) },
              { label: 'Active', values: closure.map((c) => c.activeCount) },
            ]}
          />
        </div>
      </div>

      <div className="grid grid-3">
        <div className="card">
          <h3>Assets mix</h3>
          <p className="muted">Total {formatCurrency(k.assetsTotal)}</p>
          <PieChart labels={assetPie.labels} values={assetPie.values} />
        </div>
        <div className="card">
          <h3>Money given to people</h3>
          <p className="muted">Total {formatCurrency(k.moneyGivenTotal)}</p>
          <PieChart labels={givenPie.labels} values={givenPie.values} doughnut />
        </div>
        <div className="card">
          <h3>Quick stats</h3>
          <div className="stat-row">
            <span>CC spends this month</span>
            <strong>{formatCurrency(k.ccSpendMonth)}</strong>
          </div>
          <div className="stat-row">
            <span>Events tracked</span>
            <strong>{k.eventsCount}</strong>
          </div>
          <div className="stat-row">
            <span>Assets total</span>
            <strong>{formatCurrency(k.assetsTotal)}</strong>
          </div>
          <div className="stat-row">
            <span>Money lent out</span>
            <strong>{formatCurrency(k.moneyGivenTotal)}</strong>
          </div>
        </div>
      </div>
    </div>
  );
}
