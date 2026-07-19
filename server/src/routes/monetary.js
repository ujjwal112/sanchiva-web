import { Router } from 'express';
import { query } from '../db.js';

const router = Router();

async function maybeAddAssetType(type) {
  if (!type || type.toLowerCase() === 'other') return;
  await query(
    `INSERT INTO custom_categories (section, name) VALUES ('asset', $1)
     ON CONFLICT (section, name) DO NOTHING`,
    [type]
  );
}

// ---- Income ----
router.get('/income', async (req, res) => {
  try {
    const { month, year } = req.query;
    let sql = 'SELECT * FROM income_sources WHERE 1=1';
    const params = [];
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
    const now = new Date();
    const month = Number(req.query.month) || now.getMonth() + 1;
    const year = Number(req.query.year) || now.getFullYear();

    const { rows: incomes } = await query(
      'SELECT * FROM income_sources WHERE month = $1 AND year = $2',
      [month, year]
    );
    const totalIncome = incomes.reduce((s, r) => s + Number(r.amount), 0);

    const { rows: spends } = await query(
      `SELECT COALESCE(SUM(amount), 0) AS total FROM daily_expenses
       WHERE EXTRACT(MONTH FROM expense_date) = $1 AND EXTRACT(YEAR FROM expense_date) = $2`,
      [month, year]
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
      `INSERT INTO income_sources (source_name, amount, month, year)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [source_name, amount, month, year]
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
       WHERE id = $5 RETURNING *`,
      [source_name, amount, month, year, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/income/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM income_sources WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---- Assets ----
router.get('/assets', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM assets ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/assets/summary', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM assets');
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
    let { asset_type, amount, notes, custom_type } = req.body;
    if (asset_type === 'Other' && custom_type) {
      asset_type = custom_type.trim();
      await maybeAddAssetType(asset_type);
    }
    if (!asset_type || amount == null) {
      return res.status(400).json({ error: 'asset_type and amount required' });
    }
    const { rows } = await query(
      `INSERT INTO assets (asset_type, amount, notes) VALUES ($1,$2,$3) RETURNING *`,
      [asset_type, amount, notes || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/assets/:id', async (req, res) => {
  try {
    let { asset_type, amount, notes, custom_type } = req.body;
    if (asset_type === 'Other' && custom_type) {
      asset_type = custom_type.trim();
      await maybeAddAssetType(asset_type);
    }
    const { rows } = await query(
      `UPDATE assets SET
         asset_type = COALESCE($1, asset_type),
         amount = COALESCE($2, amount),
         notes = COALESCE($3, notes),
         updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [asset_type, amount, notes, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/assets/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM assets WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---- Money Given (Lent / Personal advances) ----
router.get('/money-given', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM money_given ORDER BY given_date DESC, id DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/money-given/summary', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM money_given');
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
      `INSERT INTO money_given (person_name, given_date, amount, notes)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [person_name, given_date, amount, notes || null]
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
       WHERE id = $5 RETURNING *`,
      [person_name, given_date, amount, notes, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/money-given/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM money_given WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
