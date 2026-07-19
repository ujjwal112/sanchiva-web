import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

async function maybeAddAssetType(uid, type) {
  if (!type || type.toLowerCase() === 'other') return;
  await query(
    `INSERT INTO custom_categories (user_id, section, name) VALUES ($1, 'asset', $2)
     ON CONFLICT (user_id, section, name) DO NOTHING`,
    [uid, type]
  );
}

router.get('/income', async (req, res) => {
  try {
    const { month, year } = req.query;
    let sql = 'SELECT * FROM income_sources WHERE user_id = $1';
    const params = [userId(req)];
    if (month) {
      params.push(Number(month));
      sql += ` AND month = $${params.length}`;
    }
    if (year) {
      params.push(Number(year));
      sql += ` AND year = $${params.length}`;
    }
    sql += ' ORDER BY year DESC, month DESC, id DESC';
    const { rows } = await query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/income/summary', async (req, res) => {
  try {
    const uid = userId(req);
    const now = new Date();
    const month = Number(req.query.month) || now.getMonth() + 1;
    const year = Number(req.query.year) || now.getFullYear();
    const { rows: incomes } = await query(
      'SELECT * FROM income_sources WHERE user_id = $1 AND month = $2 AND year = $3',
      [uid, month, year]
    );
    const totalIncome = incomes.reduce((s, r) => s + Number(r.amount), 0);
    const { rows: spends } = await query(
      `SELECT COALESCE(SUM(amount), 0) AS total FROM daily_expenses
       WHERE user_id = $1 AND EXTRACT(MONTH FROM expense_date) = $2 AND EXTRACT(YEAR FROM expense_date) = $3`,
      [uid, month, year]
    );
    const totalSpend = Number(spends[0].total);
    res.json({
      month,
      year,
      incomes,
      totalIncome,
      totalSpend,
      balance: totalIncome - totalSpend,
      bySource: incomes.map((i) => ({ name: i.source_name, amount: Number(i.amount) })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/income', async (req, res) => {
  try {
    const { source_name, amount, month, year } = req.body;
    if (!source_name || amount == null || !month || !year) {
      return res.status(400).json({ error: 'source_name, amount, month, year required' });
    }
    const { rows } = await query(
      `INSERT INTO income_sources (user_id, source_name, amount, month, year)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [userId(req), source_name, amount, month, year]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/income/:id', async (req, res) => {
  try {
    const { source_name, amount, month, year } = req.body;
    const { rows } = await query(
      `UPDATE income_sources SET
         source_name = COALESCE($1, source_name),
         amount = COALESCE($2, amount),
         month = COALESCE($3, month),
         year = COALESCE($4, year),
         updated_at = NOW()
       WHERE id = $5 AND user_id = $6 RETURNING *`,
      [source_name, amount, month, year, req.params.id, userId(req)]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/income/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM income_sources WHERE id = $1 AND user_id = $2', [
      req.params.id,
      userId(req),
    ]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/assets', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM assets WHERE user_id = $1 ORDER BY created_at DESC', [
      userId(req),
    ]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/assets/summary', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM assets WHERE user_id = $1', [userId(req)]);
    const byType = {};
    let total = 0;
    for (const r of rows) {
      const amt = Number(r.amount);
      total += amt;
      byType[r.asset_type] = (byType[r.asset_type] || 0) + amt;
    }
    res.json({
      total,
      byType: Object.entries(byType).map(([name, amount]) => ({ name, amount })),
      count: rows.length,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/assets', async (req, res) => {
  try {
    const uid = userId(req);
    let { asset_type, amount, notes, custom_type } = req.body;
    if (asset_type === 'Other' && custom_type) {
      asset_type = custom_type.trim();
      await maybeAddAssetType(uid, asset_type);
    }
    if (!asset_type || amount == null) {
      return res.status(400).json({ error: 'asset_type and amount required' });
    }
    const { rows } = await query(
      `INSERT INTO assets (user_id, asset_type, amount, notes) VALUES ($1,$2,$3,$4) RETURNING *`,
      [uid, asset_type, amount, notes || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/assets/:id', async (req, res) => {
  try {
    const uid = userId(req);
    let { asset_type, amount, notes, custom_type } = req.body;
    if (asset_type === 'Other' && custom_type) {
      asset_type = custom_type.trim();
      await maybeAddAssetType(uid, asset_type);
    }
    const { rows } = await query(
      `UPDATE assets SET
         asset_type = COALESCE($1, asset_type),
         amount = COALESCE($2, amount),
         notes = COALESCE($3, notes),
         updated_at = NOW()
       WHERE id = $4 AND user_id = $5 RETURNING *`,
      [asset_type, amount, notes, req.params.id, uid]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/assets/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM assets WHERE id = $1 AND user_id = $2', [
      req.params.id,
      userId(req),
    ]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/money-given', async (req, res) => {
  try {
    const { rows } = await query(
      'SELECT * FROM money_given WHERE user_id = $1 ORDER BY given_date DESC, id DESC',
      [userId(req)]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/money-given/summary', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM money_given WHERE user_id = $1', [userId(req)]);
    const byPerson = {};
    let total = 0;
    for (const r of rows) {
      const amt = Number(r.amount);
      total += amt;
      byPerson[r.person_name] = (byPerson[r.person_name] || 0) + amt;
    }
    res.json({
      total,
      byPerson: Object.entries(byPerson).map(([name, amount]) => ({ name, amount })),
      count: rows.length,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/money-given', async (req, res) => {
  try {
    const { person_name, given_date, amount, notes } = req.body;
    if (!person_name || !given_date || amount == null) {
      return res.status(400).json({ error: 'person_name, given_date, amount required' });
    }
    const { rows } = await query(
      `INSERT INTO money_given (user_id, person_name, given_date, amount, notes)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [userId(req), person_name, given_date, amount, notes || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/money-given/:id', async (req, res) => {
  try {
    const { person_name, given_date, amount, notes } = req.body;
    const { rows } = await query(
      `UPDATE money_given SET
         person_name = COALESCE($1, person_name),
         given_date = COALESCE($2, given_date),
         amount = COALESCE($3, amount),
         notes = COALESCE($4, notes),
         updated_at = NOW()
       WHERE id = $5 AND user_id = $6 RETURNING *`,
      [person_name, given_date, amount, notes, req.params.id, userId(req)]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/money-given/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM money_given WHERE id = $1 AND user_id = $2', [
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
