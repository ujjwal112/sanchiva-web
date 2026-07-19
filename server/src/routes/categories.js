import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

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
      'SELECT name FROM custom_categories WHERE section = $1 AND user_id = $2 ORDER BY name',
      [section, userId(req)]
    );
    const custom = rows.map((r) => r.name);
    const withoutOther = [...new Set([...defaults.filter((d) => d !== 'Other'), ...custom])];
    res.json({ categories: [...withoutOther, 'Other'], custom });
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
      `INSERT INTO custom_categories (user_id, section, name)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, section, name) DO UPDATE SET name = EXCLUDED.name
       RETURNING *`,
      [userId(req), section, name]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
