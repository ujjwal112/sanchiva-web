import { Router } from 'express';
import { query } from '../db.js';
import { loanProgress } from '../utils.js';

const router = Router();

router.get('/', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM loans ORDER BY created_at DESC');
    const enriched = rows.map((loan) => ({ ...loan, progress: loanProgress(loan) }));
    res.json(enriched);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/summary', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM loans ORDER BY id');
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    let totalLoanAmount = 0;
    let deductedThisMonth = 0;
    let remainingToDeduct = 0;
    let monthlyEmiAll = 0;
    let activeCount = 0;
    let closedCount = 0;

    const byBank = {};
    const byCloseYear = {};

    for (const loan of rows) {
      const p = loanProgress(loan, now);
      totalLoanAmount += p.totalAmount;

      if (loan.status === 'closed') {
        closedCount += 1;
      } else {
        activeCount += 1;
        monthlyEmiAll += Number(loan.emi_amount);
        // deducted this month if still ongoing and not past close
        const closeKey = loan.emi_close_year * 12 + loan.emi_close_month;
        const curKey = year * 12 + month;
        if (curKey <= closeKey) {
          deductedThisMonth += Number(loan.emi_amount);
        }
        remainingToDeduct += p.remaining;
      }

      const bank = loan.emi_deduction_bank;
      if (!byBank[bank]) {
        byBank[bank] = { bank, totalEmi: 0, activeLoans: 0, closedLoans: 0 };
      }
      if (loan.status === 'ongoing') {
        byBank[bank].totalEmi += Number(loan.emi_amount);
        byBank[bank].activeLoans += 1;
      } else {
        byBank[bank].closedLoans += 1;
      }

      const cy = loan.emi_close_year;
      if (!byCloseYear[cy]) {
        byCloseYear[cy] = {
          year: cy,
          closingCount: 0,
          closedCount: 0,
          activeCount: 0,
        };
      }
      byCloseYear[cy].closingCount += 1;
      if (loan.status === 'closed') byCloseYear[cy].closedCount += 1;
      else byCloseYear[cy].activeCount += 1;
    }

    res.json({
      monthCard: {
        month,
        year,
        totalLoanAmount,
        deductedThisMonth,
        remainingToDeduct,
      },
      bankCard: {
        banks: Object.values(byBank),
        totalActiveLoans: activeCount,
        totalMonthlyEmi: monthlyEmiAll,
        closedLoansCount: closedCount,
      },
      closureYearCard: Object.values(byCloseYear).sort((a, b) => a.year - b.year),
      loans: rows.map((l) => ({ ...l, progress: loanProgress(l, now) })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const {
      bank_name,
      emi_deduction_bank,
      emi_deduction_date,
      emi_close_month,
      emi_close_year,
      emi_amount,
      status = 'ongoing',
      start_month,
      start_year,
    } = req.body;

    if (!bank_name || !emi_deduction_bank || !emi_deduction_date || !emi_close_month || !emi_close_year || emi_amount == null) {
      return res.status(400).json({ error: 'Missing required loan fields' });
    }

    const sm = start_month || new Date().getMonth() + 1;
    const sy = start_year || new Date().getFullYear();

    const { rows } = await query(
      `INSERT INTO loans
       (bank_name, emi_deduction_bank, emi_deduction_date, emi_close_month, emi_close_year, emi_amount, status, start_month, start_year)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [bank_name, emi_deduction_bank, emi_deduction_date, emi_close_month, emi_close_year, emi_amount, status, sm, sy]
    );
    res.status(201).json({ ...rows[0], progress: loanProgress(rows[0]) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const fields = [
      'bank_name',
      'emi_deduction_bank',
      'emi_deduction_date',
      'emi_close_month',
      'emi_close_year',
      'emi_amount',
      'status',
      'start_month',
      'start_year',
    ];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No fields to update' });
    params.push(req.params.id);
    const { rows } = await query(
      `UPDATE loans SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json({ ...rows[0], progress: loanProgress(rows[0]) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM loans WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
