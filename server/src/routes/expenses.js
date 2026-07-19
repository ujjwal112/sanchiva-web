import { Router } from 'express';
import { query } from '../db.js';
import { formatDate, getWeekStart } from '../utils.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

async function maybeAddCategory(uid, category) {
  if (!category || category.toLowerCase() === 'other') return;
  await query(
    `INSERT INTO custom_categories (user_id, section, name) VALUES ($1, 'expense', $2)
     ON CONFLICT (user_id, section, name) DO NOTHING`,
    [uid, category]
  );
}

router.get('/', async (req, res) => {
  try {
    const uid = userId(req);
    const { from, to, month, year } = req.query;
    let sql = 'SELECT * FROM daily_expenses WHERE user_id = $1';
    const params = [uid];
    if (from) {
      params.push(from);
      sql += ` AND expense_date >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      sql += ` AND expense_date <= $${params.length}`;
    }
    if (month && year) {
      params.push(Number(year), Number(month));
      sql += ` AND EXTRACT(YEAR FROM expense_date) = $${params.length - 1} AND EXTRACT(MONTH FROM expense_date) = $${params.length}`;
    }
    sql += ' ORDER BY expense_date DESC, id DESC';
    const { rows } = await query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/summary/weeks', async (req, res) => {
  try {
    const uid = userId(req);
    const year = Number(req.query.year) || new Date().getFullYear();
    const month = req.query.month ? Number(req.query.month) : null;
    let sql = 'SELECT * FROM daily_expenses WHERE user_id = $1 AND EXTRACT(YEAR FROM expense_date) = $2';
    const params = [uid, year];
    if (month) {
      params.push(month);
      sql += ` AND EXTRACT(MONTH FROM expense_date) = $3`;
    }
    sql += ' ORDER BY expense_date ASC';
    const { rows } = await query(sql, params);

    const weeksMap = new Map();
    for (const row of rows) {
      const weekStart = getWeekStart(row.expense_date);
      const key = formatDate(weekStart);
      if (!weeksMap.has(key)) {
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekEnd.getDate() + 6);
        weeksMap.set(key, {
          weekStart: key,
          weekEnd: formatDate(weekEnd),
          total: 0,
          byCategory: {},
          expenses: [],
        });
      }
      const w = weeksMap.get(key);
      const amt = Number(row.amount);
      w.total += amt;
      w.byCategory[row.category] = (w.byCategory[row.category] || 0) + amt;
      w.expenses.push(row);
    }
    res.json(Array.from(weeksMap.values()).reverse());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/summary/months', async (req, res) => {
  try {
    const uid = userId(req);
    const year = Number(req.query.year) || new Date().getFullYear();
    const { rows } = await query(
      `SELECT * FROM daily_expenses
       WHERE user_id = $1 AND EXTRACT(YEAR FROM expense_date) = $2
       ORDER BY expense_date ASC`,
      [uid, year]
    );
    const monthsMap = new Map();
    for (const row of rows) {
      const d = new Date(row.expense_date);
      const m = d.getMonth() + 1;
      if (!monthsMap.has(m)) {
        monthsMap.set(m, { month: m, year, total: 0, byCategory: {}, expenses: [] });
      }
      const bucket = monthsMap.get(m);
      const amt = Number(row.amount);
      bucket.total += amt;
      bucket.byCategory[row.category] = (bucket.byCategory[row.category] || 0) + amt;
      bucket.expenses.push(row);
    }
    res.json(Array.from(monthsMap.values()).sort((a, b) => b.month - a.month));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const uid = userId(req);
    let { category, amount, expense_date, item_name, custom_category } = req.body;
    if (category === 'Other' && custom_category) {
      category = custom_category.trim();
      await maybeAddCategory(uid, category);
    }
    if (!category || amount == null || !expense_date || !item_name) {
      return res.status(400).json({ error: 'category, amount, expense_date, item_name required' });
    }
    const { rows } = await query(
      `INSERT INTO daily_expenses (user_id, category, amount, expense_date, item_name)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [uid, category, amount, expense_date, item_name]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const uid = userId(req);
    let { category, amount, expense_date, item_name, custom_category } = req.body;
    if (category === 'Other' && custom_category) {
      category = custom_category.trim();
      await maybeAddCategory(uid, category);
    }
    const { rows } = await query(
      `UPDATE daily_expenses
       SET category = COALESCE($1, category),
           amount = COALESCE($2, amount),
           expense_date = COALESCE($3, expense_date),
           item_name = COALESCE($4, item_name),
           updated_at = NOW()
       WHERE id = $5 AND user_id = $6 RETURNING *`,
      [category, amount, expense_date, item_name, req.params.id, uid]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM daily_expenses WHERE id = $1 AND user_id = $2', [
      req.params.id,
      userId(req),
    ]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
