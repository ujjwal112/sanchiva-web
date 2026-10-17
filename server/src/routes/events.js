import { Router } from 'express';
import { query } from '../db.js';
import { clientLocalDate, istTodayYmd } from '../localDate.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

/** Ceremony quote + theme key (stored in metadata for overview cards) */
function ceremonyQuote(name = '') {
  const n = String(name).toLowerCase();
  if (n.includes('haldi') || n.includes('pithi')) {
    return 'May turmeric bring you glow, joy, and a lifetime of blessings.';
  }
  if (n.includes('mehend') || n.includes('mehndi') || n.includes('henna')) {
    return 'Every leaf of mehendi is a wish for love that lasts forever.';
  }
  if (n.includes('sangeet') || n.includes('garba')) {
    return 'Dance like the music was written for your forever.';
  }
  if (n.includes('tilak')) {
    return 'A sacred mark of blessing as two families join in joy.';
  }
  if (n.includes('engag') || n.includes('roka') || n.includes('sagai')) {
    return 'Two hearts, one promise, a beautiful lifetime ahead.';
  }
  if (n.includes('nikah') || n.includes('nikaah')) {
    return 'May faith and love guide every step of your journey together.';
  }
  if (n.includes('walima') || n.includes('mehfil')) {
    return 'May this feast of joy mark the start of endless happiness.';
  }
  if (n.includes('reception') || n.includes('party')) {
    return 'Celebrating love with the ones who matter most.';
  }
  if (n.includes('wedding') || n.includes('shaadi') || n.includes('vivah') || n.includes('main')) {
    return 'Today we begin a beautiful forever, hand in hand.';
  }
  return 'Celebrating this special moment with love, laughter, and joy.';
}

function ceremonyThemeKey(name = '') {
  const n = String(name).toLowerCase();
  if (n.includes('haldi') || n.includes('pithi')) return 'haldi';
  if (n.includes('mehend') || n.includes('mehndi') || n.includes('henna')) return 'mehendi';
  if (n.includes('sangeet') || n.includes('garba')) return 'sangeet';
  if (n.includes('tilak')) return 'tilak';
  if (n.includes('engag') || n.includes('roka') || n.includes('sagai')) return 'engagement';
  if (n.includes('nikah') || n.includes('nikaah')) return 'nikah';
  if (n.includes('walima') || n.includes('mehfil')) return 'walima';
  if (n.includes('reception') || n.includes('party')) return 'reception';
  if (n.includes('wedding') || n.includes('shaadi') || n.includes('vivah') || n.includes('main')) {
    return 'wedding';
  }
  return 'default';
}

function isRealCeremony(name) {
  if (!name) return false;
  const n = String(name).trim();
  if (!n) return false;
  const lower = n.toLowerCase();
  return lower !== 'other' && lower !== 'general';
}

/** Build ceremony_details from wizard answers (names + per-ceremony dates) */
function buildCeremonyDetails(answers = {}) {
  const names = Array.isArray(answers.ceremonies)
    ? answers.ceremonies
    : String(answers.ceremonies || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);

  const real = names.filter(isRealCeremony);
  return real.map((name, i) => {
    const date =
      answers[`ceremony_date_${i}`] ||
      answers[`ceremony_date__${name}`] ||
      null;
    return {
      name,
      date: date || null,
      quote: ceremonyQuote(name),
      theme: ceremonyThemeKey(name),
    };
  });
}

function parseMeta(raw) {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

/**
 * Lifecycle tag for an event:
 * - completed — has todos and every todo is closed
 * - ongoing — on/after the event day (and not all todos closed)
 * - planning — before the event day (or undated, with open/no todos)
 */
function deriveEventStatus(eventDate, itemsDone = 0, itemsTotal = 0, todayYmd = null) {
  const total = Number(itemsTotal) || 0;
  const done = Number(itemsDone) || 0;
  if (total > 0 && done >= total) return 'completed';
  if (eventDate) {
    const day = String(eventDate).slice(0, 10);
    if (/^\d{4}-\d{2}-\d{2}$/.test(day)) {
      const today = todayYmd || istTodayYmd();
      if (day <= today) return 'ongoing';
    }
  }
  return 'planning';
}

/** Recompute + persist status from event_date + todo completion. */
async function syncEventStatus(eventId) {
  const { rows } = await query(
    `SELECT e.event_date,
            COUNT(i.id)::int AS items_total,
            COUNT(i.id) FILTER (WHERE i.is_done)::int AS items_done
     FROM events e
     LEFT JOIN event_items i ON i.event_id = e.id
     WHERE e.id = $1
     GROUP BY e.id, e.event_date`,
    [eventId]
  );
  if (!rows[0]) return null;
  const status = deriveEventStatus(
    rows[0].event_date,
    rows[0].items_done,
    rows[0].items_total,
    istTodayYmd()
  );
  await query(`UPDATE events SET status = $1, updated_at = NOW() WHERE id = $2`, [status, eventId]);
  return { status, items_done: rows[0].items_done, items_total: rows[0].items_total };
}

function withDerivedStatus(row, todayYmd = null) {
  const itemsTotal = Number(row.items_total ?? row.itemsTotal ?? 0) || 0;
  const itemsDone = Number(row.items_done ?? row.itemsDone ?? 0) || 0;
  return {
    ...row,
    items_total: itemsTotal,
    items_done: itemsDone,
    status: deriveEventStatus(row.event_date, itemsDone, itemsTotal, todayYmd),
  };
}

async function assertEventOwner(eventId, uid) {
  const { rows } = await query('SELECT id FROM events WHERE id = $1 AND user_id = $2', [eventId, uid]);
  return rows[0];
}

const EVENT_PAID_VIA = new Set(['UPI', 'Cash', 'Card', 'Bank transfer', 'Wallet']);

function normalizeEventPaidVia(raw) {
  const v = String(raw || 'UPI').trim();
  if (EVENT_PAID_VIA.has(v)) return v;
  const lower = v.toLowerCase();
  if (lower === 'upi') return 'UPI';
  if (lower === 'cash') return 'Cash';
  if (lower === 'card') return 'Card';
  if (lower.includes('bank')) return 'Bank transfer';
  if (lower.includes('wallet')) return 'Wallet';
  return 'UPI';
}

/** token_paid / remaining always follow the sum of payment rows. */
async function resyncItemPaidFromPayments(itemId) {
  const { rows: sumRows } = await query(
    `SELECT COALESCE(SUM(amount), 0)::float AS paid
     FROM event_item_payments WHERE item_id = $1`,
    [itemId]
  );
  const paid = Number(sumRows[0]?.paid) || 0;
  const { rows } = await query(
    `UPDATE event_items SET
       token_paid = $1,
       remaining_amount = GREATEST(planned_amount - $1, 0),
       updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [paid, itemId]
  );
  return rows[0] || null;
}

/**
 * Older todos only had token_paid. Seed one legacy payment so history matches paid total.
 */
async function backfillItemPaymentsIfNeeded(item) {
  if (!item?.id) return;
  const paid = Number(item.token_paid) || 0;
  if (paid <= 0) return;
  const { rows } = await query(
    `SELECT COUNT(*)::int AS c FROM event_item_payments WHERE item_id = $1`,
    [item.id]
  );
  if ((rows[0]?.c || 0) > 0) return;
  const dateRaw = item.created_at || item.updated_at;
  const ymd =
    dateRaw && String(dateRaw).length >= 10
      ? String(dateRaw).slice(0, 10)
      : istTodayYmd();
  await query(
    `INSERT INTO event_item_payments
       (item_id, amount, payment_date, paid_via, paid_via_detail, notes)
     VALUES ($1, $2, $3::date, 'Other', 'Previously recorded', 'Migrated from paid total')`,
    [item.id, paid, ymd]
  );
}

async function assertItemOwner(itemId, uid) {
  const { rows } = await query(
    `SELECT ei.id, ei.event_id, ei.planned_amount, ei.token_paid, ei.created_at, ei.updated_at
     FROM event_items ei
     JOIN events e ON e.id = ei.event_id
     WHERE ei.id = $1 AND e.user_id = $2`,
    [itemId, uid]
  );
  return rows[0] || null;
}

async function listPaymentsForItem(itemId) {
  const { rows } = await query(
    `SELECT * FROM event_item_payments
     WHERE item_id = $1
     ORDER BY payment_date DESC, id DESC`,
    [itemId]
  );
  return rows;
}

async function attachPaymentsToItems(items) {
  if (!items.length) return items;
  for (const item of items) {
    await backfillItemPaymentsIfNeeded(item);
  }
  const ids = items.map((i) => i.id);
  const { rows } = await query(
    `SELECT * FROM event_item_payments
     WHERE item_id = ANY($1::int[])
     ORDER BY payment_date DESC, id DESC`,
    [ids]
  );
  const byItem = new Map();
  for (const p of rows) {
    const key = p.item_id;
    if (!byItem.has(key)) byItem.set(key, []);
    byItem.get(key).push(p);
  }
  return items.map((item) => ({
    ...item,
    payments: byItem.get(item.id) || [],
  }));
}

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
    // Extra todos for selected / custom ceremonies
    const ceremonies = Array.isArray(answers.ceremonies)
      ? answers.ceremonies
      : String(answers.ceremonies || '')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);
    for (const c of ceremonies) {
      if (!c || c.toLowerCase() === 'other') continue;
      push(`${c} ceremony planning`, 'Rituals', 0);
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

/** AI-style question flow for event creation, must be before /:id */
router.get('/meta/wizard-questions/:eventType', (req, res) => {
  const type = (req.params.eventType || '').toLowerCase();
  const common = [
    { id: 'name', label: 'What is the event name?', type: 'text', required: true },
    { id: 'event_date', label: 'When does the event start?', type: 'date', required: true },
    { id: 'days', label: 'How many days is the event?', type: 'number', required: true, default: 1 },
    { id: 'location', label: 'Where will it be held?', type: 'text' },
    { id: 'budget', label: 'What is your total budget? ({currency})', type: 'number' },
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
      { id: 'venue_budget', label: 'Venue budget estimate ({currency})', type: 'number' },
      { id: 'photo_budget', label: 'Photography budget ({currency})', type: 'number' },
      { id: 'food_budget', label: 'Catering budget ({currency})', type: 'number' },
      {
        id: 'ceremonies',
        label: 'Which ceremonies do you plan?',
        type: 'multiselect',
        allowCustom: true,
        options: [
          'Tilak',
          'Engagement',
          'Haldi',
          'Mehendi',
          'Sangeet',
          'Main Wedding',
          'Reception',
          'Other',
        ],
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

router.get('/', async (req, res) => {
  try {
    // Upcoming first (soonest on top), then undated, then past (most recent past first).
    // Include todo counts so clients can show Planning / Ongoing / Completed.
    // Order vs the phone's local calendar day (not UTC CURRENT_DATE).
    const todayYmd = clientLocalDate(req).ymd;
    const { rows } = await query(
      `SELECT e.*,
              COALESCE(c.items_total, 0)::int AS items_total,
              COALESCE(c.items_done, 0)::int AS items_done
       FROM events e
       LEFT JOIN (
         SELECT event_id,
                COUNT(*)::int AS items_total,
                COUNT(*) FILTER (WHERE is_done)::int AS items_done
         FROM event_items
         GROUP BY event_id
       ) c ON c.event_id = e.id
       WHERE e.user_id = $1
       ORDER BY
         CASE
           WHEN e.event_date IS NULL THEN 1
           WHEN e.event_date::date < $2::date THEN 2
           ELSE 0
         END,
         CASE
           WHEN e.event_date IS NOT NULL AND e.event_date::date >= $2::date
           THEN e.event_date
         END ASC NULLS LAST,
         CASE
           WHEN e.event_date IS NOT NULL AND e.event_date::date < $2::date
           THEN e.event_date
         END DESC NULLS LAST,
         e.created_at DESC`,
      [userId(req), todayYmd]
    );
    res.json(rows.map((r) => withDerivedStatus(r, todayYmd)));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM events WHERE id = $1 AND user_id = $2', [
      req.params.id,
      userId(req),
    ]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    const { rows: rawItems } = await query(
      'SELECT * FROM event_items WHERE event_id = $1 ORDER BY sort_order, id',
      [req.params.id]
    );
    const items = await attachPaymentsToItems(rawItems);
    const { rows: guests } = await query(
      'SELECT * FROM event_guests WHERE event_id = $1 ORDER BY ceremony, id',
      [req.params.id]
    );
    const planned = items.reduce((s, i) => s + Number(i.planned_amount), 0);
    const paid = items.reduce((s, i) => s + Number(i.token_paid), 0);
    const remaining = items.reduce(
      (s, i) => s + (Number(i.remaining_amount) || Math.max(Number(i.planned_amount) - Number(i.token_paid), 0)),
      0
    );

    // Ceremonies from wizard metadata + guest ceremony values (no "General")
    const meta = parseMeta(rows[0].metadata);
    let ceremonyDetails = Array.isArray(meta.ceremony_details)
      ? meta.ceremony_details.filter((d) => d && isRealCeremony(d.name))
      : [];

    // Backfill details from plain ceremonies list if older events
    if (!ceremonyDetails.length && Array.isArray(meta.ceremonies)) {
      ceremonyDetails = meta.ceremonies.filter(isRealCeremony).map((name) => ({
        name: String(name),
        date: null,
        quote: ceremonyQuote(name),
        theme: ceremonyThemeKey(name),
      }));
    }

    const fromMeta = ceremonyDetails.map((d) => d.name);
    const fromGuests = [
      ...new Set(
        guests
          .map((g) => (g.ceremony || '').trim())
          .filter((c) => isRealCeremony(c))
      ),
    ];
    // Prefer order from ceremony_details, then any extra guest ceremonies
    const ceremonies = [...new Set([...fromMeta, ...fromGuests])];

    // Ensure ceremony_details covers every ceremony name (for overview cards)
    const detailByName = Object.fromEntries(ceremonyDetails.map((d) => [d.name, d]));
    const fullCeremonyDetails = ceremonies.map((name) => {
      if (detailByName[name]) return detailByName[name];
      return {
        name,
        date: null,
        quote: ceremonyQuote(name),
        theme: ceremonyThemeKey(name),
      };
    });

    const guestsByCeremony = {};
    for (const c of ceremonies) guestsByCeremony[c] = [];
    for (const g of guests) {
      const key = (g.ceremony || '').trim();
      if (!isRealCeremony(key)) continue; // skip General / empty
      if (!guestsByCeremony[key]) guestsByCeremony[key] = [];
      guestsByCeremony[key].push(g);
    }
    const ceremonyCounts = Object.fromEntries(
      Object.entries(guestsByCeremony).map(([c, list]) => [
        c,
        list.reduce((s, g) => s + (Number(g.count) || 1), 0),
      ])
    );

    const itemsDone = items.filter((i) => i.is_done).length;
    const itemsTotal = items.length;
    const status = deriveEventStatus(
      rows[0].event_date,
      itemsDone,
      itemsTotal,
      clientLocalDate(req).ymd
    );
    // Keep stored status in sync for older clients / dashboards.
    if (rows[0].status !== status) {
      await query(`UPDATE events SET status = $1, updated_at = NOW() WHERE id = $2`, [
        status,
        req.params.id,
      ]);
    }

    res.json({
      ...rows[0],
      status,
      items_done: itemsDone,
      items_total: itemsTotal,
      metadata: meta,
      items,
      guests,
      ceremonies,
      ceremony_details: fullCeremonyDetails,
      guestsByCeremony,
      ceremonyCounts,
      summary: {
        planned,
        paid,
        remaining,
        itemsDone,
        itemsTotal,
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
    const ceremony_details = buildCeremonyDetails(answers);
    const ceremonies = ceremony_details.map((d) => d.name);

    const { rows } = await query(
      `INSERT INTO events (user_id, name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'planning') RETURNING *`,
      [
        userId(req),
        name,
        event_type,
        sub_type,
        event_date,
        end_date,
        location,
        budget,
        notes,
        JSON.stringify({
          ...answers,
          days,
          ceremonies,
          ceremony_details,
        }),
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

    const synced = await syncEventStatus(event.id);
    res.status(201).json({
      ...event,
      status: synced?.status || deriveEventStatus(event.event_date, 0, items.length),
      items_done: synced?.items_done ?? 0,
      items_total: synced?.items_total ?? items.length,
      items,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata } = req.body;
    if (!name || !event_type) return res.status(400).json({ error: 'name and event_type required' });
    const { rows } = await query(
      `INSERT INTO events (user_id, name, event_type, sub_type, event_date, end_date, location, budget, notes, metadata)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [userId(req), name, event_type, sub_type || null, event_date || null, end_date || null, location || null, budget || 0, notes || null, JSON.stringify(metadata || {})]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    // Status is derived from event_date + todos — do not accept manual overrides.
    const fields = ['name', 'event_type', 'sub_type', 'event_date', 'end_date', 'location', 'budget', 'notes'];
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
    params.push(req.params.id, userId(req));
    const { rows } = await query(
      `UPDATE events SET ${sets.join(', ')}, updated_at = NOW()
       WHERE id = $${params.length - 1} AND user_id = $${params.length} RETURNING *`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    const synced = await syncEventStatus(req.params.id);
    res.json(withDerivedStatus({
      ...rows[0],
      items_done: synced?.items_done ?? 0,
      items_total: synced?.items_total ?? 0,
      status: synced?.status || rows[0].status,
    }));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** Add a ceremony after event creation (overview cards) */
router.post('/:id/ceremonies', async (req, res) => {
  try {
    const eventId = req.params.id;
    const uid = userId(req);
    const { name, date } = req.body || {};
    const newName = String(name || '').trim();

    if (!newName) return res.status(400).json({ error: 'Ceremony name is required' });
    if (!isRealCeremony(newName)) {
      return res.status(400).json({ error: 'Invalid ceremony name' });
    }

    const { rows } = await query('SELECT * FROM events WHERE id = $1 AND user_id = $2', [eventId, uid]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });

    const meta = parseMeta(rows[0].metadata);
    let details = Array.isArray(meta.ceremony_details)
      ? meta.ceremony_details.filter((d) => d && isRealCeremony(d.name)).map((d) => ({ ...d }))
      : [];

    if (!details.length && Array.isArray(meta.ceremonies)) {
      details = meta.ceremonies.filter(isRealCeremony).map((n) => ({
        name: String(n),
        date: null,
        quote: ceremonyQuote(n),
        theme: ceremonyThemeKey(n),
      }));
    }

    if (details.some((d) => String(d.name).toLowerCase() === newName.toLowerCase())) {
      return res.status(400).json({ error: 'A ceremony with that name already exists' });
    }

    const dateVal = date ? String(date).slice(0, 10) : null;
    details.push({
      name: newName,
      date: dateVal,
      quote: ceremonyQuote(newName),
      theme: ceremonyThemeKey(newName),
    });

    meta.ceremony_details = details;
    meta.ceremonies = details.map((d) => d.name);
    details.forEach((d, i) => {
      meta[`ceremony_date_${i}`] = d.date || '';
    });

    await query(
      `UPDATE events SET metadata = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
      [JSON.stringify(meta), eventId, uid]
    );

    res.status(201).json({
      success: true,
      ceremony_details: details,
      ceremonies: meta.ceremonies,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** Update a ceremony name and/or date (overview cards); renames guests if name changes */
router.put('/:id/ceremonies', async (req, res) => {
  try {
    const eventId = req.params.id;
    const uid = userId(req);
    const { originalName, name, date } = req.body || {};
    const oldName = String(originalName || '').trim();
    const newName = String(name || '').trim();

    if (!oldName) return res.status(400).json({ error: 'originalName required' });
    if (!newName) return res.status(400).json({ error: 'Ceremony name is required' });
    if (!isRealCeremony(newName)) {
      return res.status(400).json({ error: 'Invalid ceremony name' });
    }

    const { rows } = await query('SELECT * FROM events WHERE id = $1 AND user_id = $2', [eventId, uid]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });

    const meta = parseMeta(rows[0].metadata);
    let details = Array.isArray(meta.ceremony_details)
      ? meta.ceremony_details.filter((d) => d && isRealCeremony(d.name)).map((d) => ({ ...d }))
      : [];

    if (!details.length && Array.isArray(meta.ceremonies)) {
      details = meta.ceremonies.filter(isRealCeremony).map((n) => ({
        name: String(n),
        date: null,
        quote: ceremonyQuote(n),
        theme: ceremonyThemeKey(n),
      }));
    }

    let idx = details.findIndex((d) => d.name === oldName);
    if (idx < 0) {
      // Ceremony only on guests, add a detail entry so it becomes editable
      details.push({
        name: oldName,
        date: null,
        quote: ceremonyQuote(oldName),
        theme: ceremonyThemeKey(oldName),
      });
      idx = details.length - 1;
    }

    if (newName !== oldName && details.some((d, i) => i !== idx && d.name === newName)) {
      return res.status(400).json({ error: 'A ceremony with that name already exists' });
    }

    const dateVal = date ? String(date).slice(0, 10) : null;
    details[idx] = {
      name: newName,
      date: dateVal,
      quote: ceremonyQuote(newName),
      theme: ceremonyThemeKey(newName),
    };

    meta.ceremony_details = details;
    meta.ceremonies = details.map((d) => d.name);

    // Keep wizard answer dates in sync when possible
    if (Array.isArray(meta.ceremonies)) {
      details.forEach((d, i) => {
        meta[`ceremony_date_${i}`] = d.date || '';
      });
    }

    await query(
      `UPDATE events SET metadata = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
      [JSON.stringify(meta), eventId, uid]
    );

    if (newName !== oldName) {
      await query(
        `UPDATE event_guests SET ceremony = $1, updated_at = NOW()
         WHERE event_id = $2 AND ceremony = $3`,
        [newName, eventId, oldName]
      );
    }

    res.json({
      success: true,
      ceremony_details: details,
      ceremonies: meta.ceremonies,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/** Remove a ceremony after event creation (overview cards); clears ceremony on guests */
router.delete('/:id/ceremonies', async (req, res) => {
  try {
    const eventId = req.params.id;
    const uid = userId(req);
    const name = String((req.query && req.query.name) || (req.body && req.body.name) || '').trim();

    if (!name) return res.status(400).json({ error: 'Ceremony name is required' });
    if (!isRealCeremony(name)) {
      return res.status(400).json({ error: 'Invalid ceremony name' });
    }

    const { rows } = await query('SELECT * FROM events WHERE id = $1 AND user_id = $2', [eventId, uid]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });

    const meta = parseMeta(rows[0].metadata);
    let details = Array.isArray(meta.ceremony_details)
      ? meta.ceremony_details.filter((d) => d && isRealCeremony(d.name)).map((d) => ({ ...d }))
      : [];

    if (!details.length && Array.isArray(meta.ceremonies)) {
      details = meta.ceremonies.filter(isRealCeremony).map((n) => ({
        name: String(n),
        date: null,
        quote: ceremonyQuote(n),
        theme: ceremonyThemeKey(n),
      }));
    }

    const before = details.length;
    details = details.filter((d) => String(d.name).toLowerCase() !== name.toLowerCase());
    if (details.length === before) {
      return res.status(404).json({ error: 'Ceremony not found' });
    }

    meta.ceremony_details = details;
    meta.ceremonies = details.map((d) => d.name);
    Object.keys(meta).forEach((k) => {
      if (/^ceremony_date_\d+$/.test(k)) delete meta[k];
    });
    details.forEach((d, i) => {
      meta[`ceremony_date_${i}`] = d.date || '';
    });

    await query(
      `UPDATE events SET metadata = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
      [JSON.stringify(meta), eventId, uid]
    );

    await query(
      `UPDATE event_guests SET ceremony = NULL, updated_at = NOW()
       WHERE event_id = $1 AND LOWER(ceremony) = LOWER($2)`,
      [eventId, name]
    );

    res.json({
      success: true,
      ceremony_details: details,
      ceremonies: meta.ceremonies,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await query('DELETE FROM events WHERE id = $1 AND user_id = $2', [
      req.params.id,
      userId(req),
    ]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Event items
router.post('/:id/items', async (req, res) => {
  try {
    if (!(await assertEventOwner(req.params.id, userId(req)))) {
      return res.status(404).json({ error: 'Not found' });
    }
    const { title, category, planned_amount = 0, token_paid = 0, due_date, vendor_name, notes } = req.body;
    if (!title) return res.status(400).json({ error: 'title required' });
    const remaining = Math.max(Number(planned_amount) - Number(token_paid), 0);
    const { rows } = await query(
      `INSERT INTO event_items
       (event_id, title, category, planned_amount, token_paid, remaining_amount, due_date, vendor_name, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [req.params.id, title, category || null, planned_amount, token_paid, remaining, due_date || null, vendor_name || null, notes || null]
    );
    await syncEventStatus(req.params.id);
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/items/:itemId', async (req, res) => {
  try {
    const own = await assertItemOwner(req.params.itemId, userId(req));
    if (!own) return res.status(404).json({ error: 'Not found' });
    const { rows: payCountRows } = await query(
      `SELECT COUNT(*)::int AS c FROM event_item_payments WHERE item_id = $1`,
      [req.params.itemId]
    );
    const hasPayments = (payCountRows[0]?.c || 0) > 0;
    // Paid total is owned by the payments list once any payment exists.
    const fields = hasPayments
      ? ['title', 'category', 'planned_amount', 'due_date', 'is_done', 'vendor_name', 'notes', 'sort_order']
      : ['title', 'category', 'planned_amount', 'token_paid', 'due_date', 'is_done', 'vendor_name', 'notes', 'sort_order'];
    const sets = [];
    const params = [];
    for (const f of fields) {
      if (req.body[f] !== undefined) {
        params.push(req.body[f]);
        sets.push(`${f} = $${params.length}`);
      }
    }
    if (!hasPayments && (req.body.planned_amount !== undefined || req.body.token_paid !== undefined)) {
      const { rows: cur } = await query(
        'SELECT planned_amount, token_paid FROM event_items WHERE id = $1',
        [req.params.itemId]
      );
      if (!cur[0]) return res.status(404).json({ error: 'Not found' });
      const planned =
        req.body.planned_amount !== undefined
          ? Number(req.body.planned_amount)
          : Number(cur[0].planned_amount);
      const paid =
        req.body.token_paid !== undefined ? Number(req.body.token_paid) : Number(cur[0].token_paid);
      params.push(Math.max(planned - paid, 0));
      sets.push(`remaining_amount = $${params.length}`);
    }
    if (!sets.length && !hasPayments) return res.status(400).json({ error: 'No fields' });
    let itemRow = null;
    if (sets.length) {
      params.push(req.params.itemId);
      const { rows } = await query(
        `UPDATE event_items SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $${params.length} RETURNING *`,
        params
      );
      if (!rows[0]) return res.status(404).json({ error: 'Not found' });
      itemRow = rows[0];
    }
    if (hasPayments) {
      itemRow = await resyncItemPaidFromPayments(req.params.itemId);
    }
    await syncEventStatus(own.event_id);
    const payments = await listPaymentsForItem(req.params.itemId);
    res.json({ ...(itemRow || own), payments });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/items/:itemId', async (req, res) => {
  try {
    const own = await assertItemOwner(req.params.itemId, userId(req));
    if (!own) return res.status(404).json({ error: 'Not found' });
    const eventId = own.event_id;
    const { rowCount } = await query(
      `DELETE FROM event_items ei USING events e
       WHERE ei.id = $1 AND ei.event_id = e.id AND e.user_id = $2`,
      [req.params.itemId, userId(req)]
    );
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    await syncEventStatus(eventId);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Todo partial payments
router.get('/items/:itemId/payments', async (req, res) => {
  try {
    const own = await assertItemOwner(req.params.itemId, userId(req));
    if (!own) return res.status(404).json({ error: 'Not found' });
    await backfillItemPaymentsIfNeeded(own);
    await resyncItemPaidFromPayments(req.params.itemId);
    res.json(await listPaymentsForItem(req.params.itemId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/items/:itemId/payments', async (req, res) => {
  try {
    const own = await assertItemOwner(req.params.itemId, userId(req));
    if (!own) return res.status(404).json({ error: 'Not found' });
    await backfillItemPaymentsIfNeeded(own);

    const amount = Number(req.body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'amount must be greater than 0' });
    }
    const local = clientLocalDate(req);
    const paymentDate = String(req.body.payment_date || local.ymd).slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(paymentDate)) {
      return res.status(400).json({ error: 'payment_date required (YYYY-MM-DD)' });
    }
    const paidVia = normalizeEventPaidVia(req.body.paid_via);
    const detail =
      paidVia === 'Cash' ? null : String(req.body.paid_via_detail || '').trim() || null;
    const notes = String(req.body.notes || '').trim() || null;

    const { rows } = await query(
      `INSERT INTO event_item_payments
         (item_id, amount, payment_date, paid_via, paid_via_detail, notes)
       VALUES ($1, $2, $3::date, $4, $5, $6)
       RETURNING *`,
      [req.params.itemId, amount, paymentDate, paidVia, detail, notes]
    );
    const item = await resyncItemPaidFromPayments(req.params.itemId);
    await syncEventStatus(own.event_id);
    res.status(201).json({
      payment: rows[0],
      item,
      payments: await listPaymentsForItem(req.params.itemId),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/payments/:paymentId', async (req, res) => {
  try {
    const { rows: ownRows } = await query(
      `SELECT p.id, p.item_id, ei.event_id, p.amount, p.payment_date, p.paid_via, p.paid_via_detail, p.notes
       FROM event_item_payments p
       JOIN event_items ei ON ei.id = p.item_id
       JOIN events e ON e.id = ei.event_id
       WHERE p.id = $1 AND e.user_id = $2`,
      [req.params.paymentId, userId(req)]
    );
    if (!ownRows[0]) return res.status(404).json({ error: 'Not found' });
    const cur = ownRows[0];
    const itemId = cur.item_id;
    const eventId = cur.event_id;

    const amount =
      req.body.amount !== undefined ? Number(req.body.amount) : Number(cur.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'amount must be greater than 0' });
    }
    const local = clientLocalDate(req);
    const paymentDate = String(req.body.payment_date || cur.payment_date || local.ymd)
      .slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(paymentDate)) {
      return res.status(400).json({ error: 'payment_date required (YYYY-MM-DD)' });
    }
    const paidVia = normalizeEventPaidVia(
      req.body.paid_via !== undefined ? req.body.paid_via : cur.paid_via
    );
    const detailRaw =
      req.body.paid_via_detail !== undefined
        ? String(req.body.paid_via_detail || '').trim()
        : String(cur.paid_via_detail || '').trim();
    const detail = paidVia === 'Cash' ? null : detailRaw || null;
    const notes =
      req.body.notes !== undefined
        ? String(req.body.notes || '').trim() || null
        : cur.notes || null;

    const { rows } = await query(
      `UPDATE event_item_payments SET
         amount = $1,
         payment_date = $2::date,
         paid_via = $3,
         paid_via_detail = $4,
         notes = $5
       WHERE id = $6
       RETURNING *`,
      [amount, paymentDate, paidVia, detail, notes, req.params.paymentId]
    );
    const item = await resyncItemPaidFromPayments(itemId);
    await syncEventStatus(eventId);
    res.json({
      payment: rows[0],
      item,
      payments: await listPaymentsForItem(itemId),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/payments/:paymentId', async (req, res) => {
  try {
    const { rows: ownRows } = await query(
      `SELECT p.id, p.item_id, ei.event_id
       FROM event_item_payments p
       JOIN event_items ei ON ei.id = p.item_id
       JOIN events e ON e.id = ei.event_id
       WHERE p.id = $1 AND e.user_id = $2`,
      [req.params.paymentId, userId(req)]
    );
    if (!ownRows[0]) return res.status(404).json({ error: 'Not found' });
    const { item_id: itemId, event_id: eventId } = ownRows[0];
    await query(`DELETE FROM event_item_payments WHERE id = $1`, [req.params.paymentId]);
    const item = await resyncItemPaidFromPayments(itemId);
    await syncEventStatus(eventId);
    res.json({
      success: true,
      item,
      payments: await listPaymentsForItem(itemId),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Guests
router.post('/:id/guests', async (req, res) => {
  try {
    if (!(await assertEventOwner(req.params.id, userId(req)))) {
      return res.status(404).json({ error: 'Not found' });
    }
    const { name, side, rsvp, count, phone, notes, ceremony } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });
    const rsvpVal = ['yes', 'no', 'maybe'].includes(rsvp) ? rsvp : 'maybe';
    const { rows } = await query(
      `INSERT INTO event_guests (event_id, name, side, ceremony, rsvp, count, phone, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [
        req.params.id,
        name,
        side || null,
        (ceremony || '').trim() || null,
        rsvpVal,
        count || 1,
        phone || null,
        notes || null,
      ]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/guests/:guestId', async (req, res) => {
  try {
    const own = await query(
      `SELECT eg.id FROM event_guests eg JOIN events e ON e.id = eg.event_id
       WHERE eg.id = $1 AND e.user_id = $2`,
      [req.params.guestId, userId(req)]
    );
    if (!own.rows[0]) return res.status(404).json({ error: 'Not found' });
    if (req.body.rsvp !== undefined && !['yes', 'no', 'maybe'].includes(req.body.rsvp)) {
      return res.status(400).json({ error: 'rsvp must be yes, no, or maybe' });
    }
    const fields = ['name', 'side', 'ceremony', 'rsvp', 'count', 'phone', 'notes'];
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
    const { rowCount } = await query(
      `DELETE FROM event_guests eg USING events e
       WHERE eg.id = $1 AND eg.event_id = e.id AND e.user_id = $2`,
      [req.params.guestId, userId(req)]
    );
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
