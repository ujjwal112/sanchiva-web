import { Router } from 'express';
import { query } from '../db.js';

const router = Router();

const DEFAULTS = {
  expense: ['Ecommerce', 'Grocery', 'Food', 'Travel', 'Electronics', 'Miscellaneous', 'Other'],
  asset: ['FD', 'RD', 'Mutual Funds', 'Stocks', 'Crypto', 'Gold', 'Silver', 'Saving Account', 'Other'],
  spend: ['Ecommerce', 'Grocery', 'Food', 'Travel', 'Electronics', 'Miscellaneous', 'Other'],
};

router.get('/:section', async (req, res) => {
  try {
    const section = req.params.section;
    const defaults = DEFAULTS[section] || [];
    const { rows } = await query(
      'SELECT name FROM custom_categories WHERE section = $1 ORDER BY name',
      [section]
    );
    const custom = rows.map((r) => r.name);
    // Merge defaults + custom, keep "Other" last
    const withoutOther = [...new Set([...defaults.filter((d) => d !== 'Other'), ...custom])];
    const list = [...withoutOther, 'Other'];
    res.json({ categories: list, custom });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:section', async (req, res) => {
  try {
    const section = req.params.section;
    const name = (req.body.name || '').trim();
    if (!name) return res.status(400).json({ error: 'Name required' });
    if (name.toLowerCase() === 'other') {
      return res.status(400).json({ error: 'Cannot add Other as custom category' });
    }
    const { rows } = await query(
      `INSERT INTO custom_categories (section, name)
       VALUES ($1, $2)
       ON CONFLICT (section, name) DO UPDATE SET name = EXCLUDED.name
       RETURNING *`,
      [section, name]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
