import { Router } from 'express';
import { query } from '../db.js';
import { loanProgress } from '../utils.js';

const router = Router();

router.get('/', async (_req, res) => {
  try {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    // Month expenses + category pie
    const { rows: monthExpenses } = await query(
      `SELECT category, SUM(amount)::float AS amount
       FROM daily_expenses
       WHERE EXTRACT(MONTH FROM expense_date) = $1 AND EXTRACT(YEAR FROM expense_date) = $2
       GROUP BY category`,
      [month, year]
    );
    const monthExpenseTotal = monthExpenses.reduce((s, r) => s + Number(r.amount), 0);

    // Last 6 months expense trend
    const { rows: trend } = await query(
      `SELECT EXTRACT(YEAR FROM expense_date)::int AS year,
              EXTRACT(MONTH FROM expense_date)::int AS month,
              SUM(amount)::float AS total
       FROM daily_expenses
       WHERE expense_date >= (CURRENT_DATE - INTERVAL '6 months')
       GROUP BY 1, 2
       ORDER BY 1, 2`
    );

    // Income this month
    const { rows: incomes } = await query(
      'SELECT COALESCE(SUM(amount),0)::float AS total FROM income_sources WHERE month = $1 AND year = $2',
      [month, year]
    );
    const monthIncome = Number(incomes[0].total);

    // Loans summary
    const { rows: loans } = await query('SELECT * FROM loans');
    let loanTotal = 0;
    let loanDeductedMonth = 0;
    let loanRemaining = 0;
    let activeLoans = 0;
    let closedLoans = 0;
    let monthlyEmi = 0;
    const byBank = {};
    const byCloseYear = {};

    for (const loan of loans) {
      const p = loanProgress(loan, now);
      loanTotal += p.totalAmount;
      if (loan.status === 'closed') {
        closedLoans += 1;
      } else {
        activeLoans += 1;
        monthlyEmi += Number(loan.emi_amount);
        const closeKey = loan.emi_close_year * 12 + loan.emi_close_month;
        const curKey = year * 12 + month;
        if (curKey <= closeKey) loanDeductedMonth += Number(loan.emi_amount);
        loanRemaining += p.remaining;
      }
      const bank = loan.emi_deduction_bank;
      if (!byBank[bank]) byBank[bank] = { bank, totalEmi: 0 };
      if (loan.status === 'ongoing') byBank[bank].totalEmi += Number(loan.emi_amount);

      const cy = loan.emi_close_year;
      if (!byCloseYear[cy]) byCloseYear[cy] = { year: cy, closingCount: 0, closedCount: 0, activeCount: 0 };
      byCloseYear[cy].closingCount += 1;
      if (loan.status === 'closed') byCloseYear[cy].closedCount += 1;
      else byCloseYear[cy].activeCount += 1;
    }

    // Assets
    const { rows: assetRows } = await query(
      `SELECT asset_type AS name, SUM(amount)::float AS amount FROM assets GROUP BY asset_type`
    );
    const assetsTotal = assetRows.reduce((s, r) => s + Number(r.amount), 0);

    // Money given
    const { rows: givenRows } = await query(
      `SELECT person_name AS name, SUM(amount)::float AS amount FROM money_given GROUP BY person_name`
    );
    const moneyGivenTotal = givenRows.reduce((s, r) => s + Number(r.amount), 0);

    // CC spends this month
    const { rows: ccMonth } = await query(
      `SELECT COALESCE(SUM(amount),0)::float AS total FROM credit_card_spends
       WHERE EXTRACT(MONTH FROM spend_date) = $1 AND EXTRACT(YEAR FROM spend_date) = $2`,
      [month, year]
    );

    // Events count
    const { rows: eventCount } = await query(`SELECT COUNT(*)::int AS c FROM events`);

    res.json({
      month,
      year,
      kpis: {
        monthExpenseTotal,
        monthIncome,
        monthBalance: monthIncome - monthExpenseTotal,
        monthlyEmi,
        activeLoans,
        closedLoans,
        assetsTotal,
        moneyGivenTotal,
        ccSpendMonth: Number(ccMonth[0].total),
        eventsCount: eventCount[0].c,
      },
      monthExpenseCard: {
        month,
        year,
        total: monthExpenseTotal,
        byCategory: monthExpenses.map((r) => ({ name: r.category, amount: Number(r.amount) })),
      },
      expenseTrend: trend.map((t) => ({
        label: `${t.year}-${String(t.month).padStart(2, '0')}`,
        total: Number(t.total),
      })),
      loanMonthCard: {
        month,
        year,
        totalLoanAmount: loanTotal,
        deductedThisMonth: loanDeductedMonth,
        remainingToDeduct: loanRemaining,
      },
      loanBankCard: {
        banks: Object.values(byBank),
        totalActiveLoans: activeLoans,
        totalMonthlyEmi: monthlyEmi,
        closedLoansCount: closedLoans,
      },
      loanClosureYearCard: Object.values(byCloseYear).sort((a, b) => a.year - b.year),
      assetsByType: assetRows,
      moneyGivenByPerson: givenRows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
