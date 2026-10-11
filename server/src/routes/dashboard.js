import { Router } from 'express';
import { query } from '../db.js';
import { clientLocalDate, addDaysYmd } from '../localDate.js';
import { loanProgress } from '../utils.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  try {
    const uid = userId(req);
    // Prefer phone local calendar day (X-Client-Local-Date); else Asia/Kolkata.
    const local = clientLocalDate(req);
    const { ymd: todayYmd, year, month, day } = local;
    const asOf = new Date(year, month - 1, day, 12, 0, 0);
    const trendFromYmd = addDaysYmd(todayYmd, -180);

    const { rows: monthExpenses } = await query(
      `SELECT category, SUM(amount)::float AS amount
       FROM daily_expenses
       WHERE user_id = $1 AND EXTRACT(MONTH FROM expense_date) = $2 AND EXTRACT(YEAR FROM expense_date) = $3
       GROUP BY category`,
      [uid, month, year]
    );
    const monthExpenseTotal = monthExpenses.reduce((s, r) => s + Number(r.amount), 0);

    const { rows: todayRows } = await query(
      `SELECT COALESCE(SUM(amount),0)::float AS total
       FROM daily_expenses
       WHERE user_id = $1 AND expense_date = $2::date`,
      [uid, todayYmd]
    );
    const todayExpenseTotal = Number(todayRows[0]?.total || 0);

    const { rows: trend } = await query(
      `SELECT EXTRACT(YEAR FROM expense_date)::int AS year,
              EXTRACT(MONTH FROM expense_date)::int AS month,
              SUM(amount)::float AS total
       FROM daily_expenses
       WHERE user_id = $1 AND expense_date >= $2::date
       GROUP BY 1, 2 ORDER BY 1, 2`,
      [uid, trendFromYmd]
    );

    const { rows: incomes } = await query(
      'SELECT COALESCE(SUM(amount),0)::float AS total FROM income_sources WHERE user_id = $1 AND month = $2 AND year = $3',
      [uid, month, year]
    );
    const monthIncome = Number(incomes[0].total);

    const { rows: loans } = await query('SELECT * FROM loans WHERE user_id = $1', [uid]);
    let loanTotal = 0;
    let loanDeductedMonth = 0;
    let loanRemaining = 0;
    let activeLoans = 0;
    let closedLoans = 0;
    let monthlyEmi = 0;
    let todayLoanEmi = 0;
    let loanEmiDeductedTillDate = 0;
    const curKey = year * 12 + month;
    const byBank = {};
    const byCloseYear = {};

    for (const loan of loans) {
      const p = loanProgress(loan, asOf);
      loanTotal += p.totalAmount;
      if (loan.status === 'closed') closedLoans += 1;
      else {
        activeLoans += 1;
        const emi = Number(loan.emi_amount) || 0;
        const startKey =
          (Number(loan.start_year) || year) * 12 + (Number(loan.start_month) || month);
        const closeKey =
          (Number(loan.emi_close_year) || year) * 12 + (Number(loan.emi_close_month) || 12);
        const dedDay = Number(loan.emi_deduction_date) || 0;
        if (curKey >= startKey && curKey <= closeKey) {
          monthlyEmi += emi;
          // Deduction day already passed or is today → counted as deducted till date.
          if (dedDay > 0 && dedDay <= day) {
            loanDeductedMonth += emi;
            loanEmiDeductedTillDate += emi;
          }
          if (dedDay === day) todayLoanEmi += emi;
        }
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

    const { rows: assetRows } = await query(
      `SELECT asset_type AS name, SUM(amount)::float AS amount FROM assets WHERE user_id = $1 GROUP BY asset_type`,
      [uid]
    );
    const assetsTotal = assetRows.reduce((s, r) => s + Number(r.amount), 0);

    const { rows: givenRows } = await query(
      `SELECT person_name AS name, SUM(amount)::float AS amount FROM money_given WHERE user_id = $1 GROUP BY person_name`,
      [uid]
    );
    const moneyGivenTotal = givenRows.reduce((s, r) => s + Number(r.amount), 0);

    const { rows: ccMonth } = await query(
      `SELECT COALESCE(SUM(amount),0)::float AS total FROM credit_card_spends
       WHERE user_id = $1 AND EXTRACT(MONTH FROM spend_date) = $2 AND EXTRACT(YEAR FROM spend_date) = $3`,
      [uid, month, year]
    );

    const { rows: eventCount } = await query(`SELECT COUNT(*)::int AS c FROM events WHERE user_id = $1`, [uid]);

    res.json({
      month,
      year,
      kpis: {
        monthExpenseTotal,
        todayExpenseTotal,
        monthIncome,
        monthBalance: monthIncome - monthExpenseTotal,
        monthlyEmi,
        todayLoanEmi,
        loanEmiDeductedTillDate,
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
