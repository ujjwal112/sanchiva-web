import { Router } from 'express';
import { query } from '../db.js';

const router = Router();

async function maybeAddSpendType(type) {
  if (!type || type.toLowerCase() === 'other') return;
  await query(
    `INSERT INTO custom_categories (section, name) VALUES ('spend', $1)
     ON CONFLICT (section, name) DO NOTHING`,
    [type]
  );
}

// ---- Spends ----
router.get('/spends', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM credit_card_spends ORDER BY spend_date DESC, id DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/spends/summary', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM credit_card_spends');
    const byType = {};
    const byCard = {};
    let total = 0;
    for (const r of rows) {
      const amt = Number(r.amount);
      total += amt;
      byType[r.spend_type] = (byType[r.spend_type] || 0) + amt;
      byCard[r.credit_card_name] = (byCard[r.credit_card_name] || 0) + amt;
    }
    res.json({
      total,
      byType: Object.entries(byType).map(([name, amount]) => ({ name, amount })),
      byCard: Object.entries(byCard).map(([name, amount]) => ({ name, amount })),
      count: rows.length,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/spends', async (req, res) => {
  try {
    let { spend_date, spend_type, credit_card_name, amount, custom_type } = req.body;
    if (spend_type === 'Other' && custom_type) {
      spend_type = custom_type.trim();
      await maybeAddSpendType(spend_type);
    }
    if (!spend_date || !spend_type || !credit_card_name || amount == null) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const { rows } = await query(
      `INSERT INTO credit_card_spends (spend_date, spend_type, credit_card_name, amount)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [spend_date, spend_type, credit_card_name, amount]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/spends/:id', async (req, res) => {
  try {
    let { spend_date, spend_type, credit_card_name, amount, custom_type } = req.body;
    if (spend_type === 'Other' && custom_type) {
      spend_type = custom_type.trim();
      await maybeAddSpendType(spend_type);
    }
    const { rows } = await query(
      `UPDATE credit_card_spends SET
         spend_date = COALESCE($1, spend_date),
         spend_type = COALESCE($2, spend_type),
         credit_card_name = COALESCE($3, credit_card_name),
         amount = COALESCE($4, amount),
         updated_at = NOW()
       WHERE id = $5 RETURNING *`,
      [spend_date, spend_type, credit_card_name, amount, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/spends/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM credit_card_spends WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---- EMIs ----
router.get('/emis', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM credit_card_emis ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/emis/summary', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM credit_card_emis');
    const byCard = {};
    let totalMonthly = 0;
    let totalOverall = 0;
    for (const r of rows) {
      const months =
        (r.end_year - r.start_year) * 12 + (r.end_month - r.start_month) + 1;
      const total = Number(r.amount) * Math.max(months, 0);
      totalMonthly += Number(r.amount);
      totalOverall += total;
      if (!byCard[r.credit_card_name]) {
        byCard[r.credit_card_name] = { name: r.credit_card_name, monthly: 0, total: 0, count: 0 };
      }
      byCard[r.credit_card_name].monthly += Number(r.amount);
      byCard[r.credit_card_name].total += total;
      byCard[r.credit_card_name].count += 1;
    }
    res.json({
      totalMonthly,
      totalOverall,
      byCard: Object.values(byCard),
      count: rows.length,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/emis', async (req, res) => {
  try {
    const { emi_name, credit_card_name, start_month, start_year, end_month, end_year, amount } = req.body;
    if (!emi_name || !credit_card_name || !start_month || !start_year || !end_month || !end_year || amount == null) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const { rows } = await query(
      `INSERT INTO credit_card_emis
       (emi_name, credit_card_name, start_month, start_year, end_month, end_year, amount)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [emi_name, credit_card_name, start_month, start_year, end_month, end_year, amount]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/emis/:id', async (req, res) => {
  try {
    const fields = ['emi_name', 'credit_card_name', 'start_month', 'start_year', 'end_month', 'end_year', 'amount'];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No fields' });
    params.push(req.params.id);
    const { rows } = await query(
      `UPDATE credit_card_emis SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/emis/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM credit_card_emis WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
