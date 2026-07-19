import { Router } from 'express';
import { query } from '../db.js';

const router = Router();

/** Template builders for common event types */
export function buildEventTemplate(eventType, answers = {}) {
  const items = [];
  const push = (title, category, amount = 0) =>
    items.push({ title, category, planned_amount: amount, token_paid: 0 });

  const type = (eventType || '').toLowerCase();

  if (type === 'wedding') {
    const style = (answers.wedding_style || answers.sub_type || 'hindu').toLowerCase();
    push('Book banquet / venue', 'Venue', answers.venue_budget || 0);
    push('Book photographer & videographer', 'Media', answers.photo_budget || 0);
    push('Catering / menu finalization', 'Food', answers.food_budget || 0);
    push('Decoration & florals', 'Decor', 0);
    push('Invitation cards / e-invites', 'Invites', 0);
    push('Mehendi artist', 'Rituals', 0);
    push('Makeup / beauty for couple', 'Beauty', 0);
    push('Music / DJ / band', 'Entertainment', 0);
    push('Guest accommodation', 'Stay', 0);
    push('Transportation for guests', 'Travel', 0);
    push('Wedding outfits (bride & groom)', 'Attire', 0);
    push('Jewelry / accessories', 'Attire', 0);
    push('Priest / officiant booking', 'Rituals', 0);
    push('Return gifts', 'Gifts', 0);
    if (style.includes('hindu')) {
      push('Haldi ceremony setup', 'Rituals', 0);
      push('Sangeet night planning', 'Entertainment', 0);
      push('Mandap decoration', 'Decor', 0);
      push('Pooja samagri', 'Rituals', 0);
    }
    if (style.includes('muslim') || style.includes('nikah')) {
      push('Nikah venue & Qazi', 'Rituals', 0);
      push('Mehfil / Walima planning', 'Events', 0);
      push('Barat arrangements', 'Events', 0);
    }
    if (style.includes('christian')) {
      push('Church booking', 'Venue', 0);
      push('Reception hall', 'Venue', 0);
    }
    if (answers.days && Number(answers.days) > 1) {
      push(`Multi-day coordination (${answers.days} days)`, 'Planning', 0);
    }
  } else if (type === 'birthday') {
    push('Venue / home setup', 'Venue', 0);
    push('Cake order', 'Food', 0);
    push('Decorations & balloons', 'Decor', 0);
    push('Catering / snacks', 'Food', 0);
    push('Entertainment / games', 'Entertainment', 0);
    push('Return gifts', 'Gifts', 0);
    push('Photographer', 'Media', 0);
    push('Invitations', 'Invites', 0);
  } else if (type === 'anniversary') {
    push('Dinner reservation / venue', 'Venue', 0);
    push('Cake / flowers', 'Gifts', 0);
    push('Photographer', 'Media', 0);
    push('Gift for partner', 'Gifts', 0);
  } else if (type === 'housewarming' || type === 'gruhapravesh') {
    push('Pooja arrangements', 'Rituals', 0);
    push('Catering', 'Food', 0);
    push('Decorations', 'Decor', 0);
    push('Invites', 'Invites', 0);
    push('Return gifts', 'Gifts', 0);
  } else if (type === 'corporate' || type === 'office') {
    push('Venue booking', 'Venue', 0);
    push('AV / projector setup', 'Tech', 0);
    push('Catering', 'Food', 0);
    push('Speakers / agenda', 'Planning', 0);
    push('Swag / gifts', 'Gifts', 0);
  } else {
    push('Main venue booking', 'Venue', 0);
    push('Catering', 'Food', 0);
    push('Decorations', 'Decor', 0);
    push('Invitations', 'Invites', 0);
    push('Photography', 'Media', 0);
    push('Entertainment', 'Entertainment', 0);
    push('Miscellaneous budget buffer', 'Other', 0);
  }

  return items;
}

/** AI-style question flow for event creation — must be before /:id */
router.get('/meta/wizard-questions/:eventType', (req, res) => {
  const type = (req.params.eventType || '').toLowerCase();
  const common = [
    { id: 'name', label: 'What is the event name?', type: 'text', required: true },
    { id: 'event_date', label: 'When does the event start?', type: 'date', required: true },
    { id: 'days', label: 'How many days is the event?', type: 'number', required: true, default: 1 },
    { id: 'location', label: 'Where will it be held?', type: 'text' },
    { id: 'budget', label: 'What is your total budget? (₹)', type: 'number' },
    { id: 'guest_estimate', label: 'Approximate number of guests?', type: 'number' },
  ];

  let specific = [];
  if (type === 'wedding') {
    specific = [
      {
        id: 'wedding_style',
        label: 'What style of wedding is this?',
        type: 'select',
        options: ['Hindu', 'Muslim / Nikah', 'Christian', 'Sikh', 'Interfaith', 'Civil / Court', 'Other'],
        required: true,
      },
      { id: 'bride_groom', label: 'Couple names (optional)', type: 'text' },
      { id: 'venue_budget', label: 'Venue budget estimate (₹)', type: 'number' },
      { id: 'photo_budget', label: 'Photography budget (₹)', type: 'number' },
      { id: 'food_budget', label: 'Catering budget (₹)', type: 'number' },
      {
        id: 'ceremonies',
        label: 'Which ceremonies do you plan?',
        type: 'multiselect',
        options: ['Engagement', 'Haldi', 'Mehendi', 'Sangeet', 'Main Wedding', 'Reception', 'Walima'],
      },
    ];
  } else if (type === 'birthday') {
    specific = [
      { id: 'celebrant', label: 'Whose birthday is it?', type: 'text', required: true },
      { id: 'age', label: 'Turning age?', type: 'number' },
      {
        id: 'theme',
        label: 'Theme (optional)',
        type: 'select',
        options: ['Kids party', 'Surprise', 'Formal dinner', 'Casual get-together', 'Other'],
      },
    ];
  } else if (type === 'anniversary') {
    specific = [
      { id: 'years', label: 'Which anniversary year?', type: 'number' },
      { id: 'partner_names', label: 'Names', type: 'text' },
    ];
  } else {
    specific = [
      { id: 'sub_type', label: 'Describe the event briefly', type: 'text' },
      {
        id: 'priority',
        label: 'Top priority for this event?',
        type: 'select',
        options: ['Budget control', 'Guest experience', 'Rituals', 'Photography', 'Food'],
      },
    ];
  }

  res.json({
    event_type: type,
    intro: `I'll help you plan a ${type || 'custom'} event. Answer a few questions and I'll build a tracker with todos, budgets, and guest list.`,
    questions: [...common, ...specific, { id: 'notes', label: 'Any extra notes?', type: 'textarea' }],
  });
});

router.get('/', async (_req, res) => {
  try {
    const { rows } = await query('SELECT * FROM events ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM events WHERE id = $1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    const { rows: items } = await query(
      'SELECT * FROM event_items WHERE event_id = $1 ORDER BY sort_order, id',
      [req.params.id]
    );
    const { rows: guests } = await query(
      'SELECT * FROM event_guests WHERE event_id = $1 ORDER BY id',
      [req.params.id]
    );
    const planned = items.reduce((s, i) => s + Number(i.planned_amount), 0);
    const paid = items.reduce((s, i) => s + Number(i.token_paid), 0);
    const remaining = items.reduce(
      (s, i) => s + (Number(i.remaining_amount) || Math.max(Number(i.planned_amount) - Number(i.token_paid), 0)),
      0
    );
    res.json({
      ...rows[0],
      items,
      guests,
      summary: {
        planned,
        paid,
        remaining,
        itemsDone: items.filter((i) => i.is_done).length,
        itemsTotal: items.length,
        guestCount: guests.reduce((s, g) => s + (g.count || 1), 0),
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/wizard', async (req, res) => {
  try {
    const { name, event_type, answers = {}, generate_todos = true } = req.body;
    if (!name || !event_type) {
      return res.status(400).json({ error: 'name and event_type required' });
    }

    const sub_type = answers.wedding_style || answers.sub_type || null;
    const event_date = answers.event_date || answers.start_date || null;
    const end_date = answers.end_date || null;
    const location = answers.location || null;
    const budget = answers.budget || 0;
    const notes = answers.notes || null;
    const days = answers.days || null;

    const { rows } = await query(
      `INSERT INTO events (name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'planning') RETURNING *`,
      [
        name,
        event_type,
        sub_type,
        event_date,
        end_date,
        location,
        budget,
        notes,
        JSON.stringify({ ...answers, days }),
      ]
    );
    const event = rows[0];

    let items = [];
    if (generate_todos) {
      const template = buildEventTemplate(event_type, { ...answers, sub_type });
      for (let i = 0; i < template.length; i++) {
        const t = template[i];
        const remaining = Math.max(Number(t.planned_amount) - Number(t.token_paid || 0), 0);
        const { rows: ir } = await query(
          `INSERT INTO event_items
           (event_id, title, category, planned_amount, token_paid, remaining_amount, sort_order)
           VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
          [event.id, t.title, t.category, t.planned_amount, t.token_paid || 0, remaining, i]
        );
        items.push(ir[0]);
      }
    }

    res.status(201).json({ ...event, items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata } = req.body;
    if (!name || !event_type) return res.status(400).json({ error: 'name and event_type required' });
    const { rows } = await query(
      `INSERT INTO events (name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [name, event_type, sub_type || null, event_date || null, end_date || null, location || null, budget || 0, notes || null, JSON.stringify(metadata || {})]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const fields = ['name', 'event_type', 'sub_type', 'event_date', 'end_date', 'location', 'budget', 'notes', 'status'];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    if (req.body.metadata !== undefined) {
      params.push(JSON.stringify(req.body.metadata));
      sets.push(`metadata = $${params.length}`);
    }
    if (!sets.length) return res.status(400).json({ error: 'No fields' });
    params.push(req.params.id);
    const { rows } = await query(
      `UPDATE events SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM events WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Event items
router.post('/:id/items', async (req, res) => {
  try {
    const { title, category, planned_amount = 0, token_paid = 0, due_date, vendor_name, notes } = req.body;
    if (!title) return res.status(400).json({ error: 'title required' });
    const remaining = Math.max(Number(planned_amount) - Number(token_paid), 0);
    const { rows } = await query(
      `INSERT INTO event_items
       (event_id, title, category, planned_amount, token_paid, remaining_amount, due_date, vendor_name, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [req.params.id, title, category || null, planned_amount, token_paid, remaining, due_date || null, vendor_name || null, notes || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/items/:itemId', async (req, res) => {
  try {
    const fields = ['title', 'category', 'planned_amount', 'token_paid', 'due_date', 'is_done', 'vendor_name', 'notes', 'sort_order'];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    // recompute remaining if amounts change
    if (req.body.planned_amount !== undefined || req.body.token_paid !== undefined) {
      const { rows: cur } = await query('SELECT planned_amount, token_paid FROM event_items WHERE id = $1', [req.params.itemId]);
      if (!cur[0]) return res.status(404).json({ error: 'Not found' });
      const planned = req.body.planned_amount !== undefined ? Number(req.body.planned_amount) : Number(cur[0].planned_amount);
      const paid = req.body.token_paid !== undefined ? Number(req.body.token_paid) : Number(cur[0].token_paid);
      params.push(Math.max(planned - paid, 0));
      sets.push(`remaining_amount = $${params.length}`);
    }
    if (!sets.length) return res.status(400).json({ error: 'No fields' });
    params.push(req.params.itemId);
    const { rows } = await query(
      `UPDATE event_items SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/items/:itemId', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM event_items WHERE id = $1', [req.params.itemId]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Guests
router.post('/:id/guests', async (req, res) => {
  try {
    const { name, side, rsvp, count, phone, notes } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });
    const { rows } = await query(
      `INSERT INTO event_guests (event_id, name, side, rsvp, count, phone, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.params.id, name, side || null, rsvp || 'pending', count || 1, phone || null, notes || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/guests/:guestId', async (req, res) => {
  try {
    const fields = ['name', 'side', 'rsvp', 'count', 'phone', 'notes'];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No fields' });
    params.push(req.params.guestId);
    const { rows } = await query(
      `UPDATE event_guests SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/guests/:guestId', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM event_guests WHERE id = $1', [req.params.guestId]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
