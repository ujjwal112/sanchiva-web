/**
 * Guest demo data: shared guest account gets rich sample rows in every
 * module, including Events of every type. On logout we wipe session changes
 * and re-seed so the baseline always returns; guest-added rows disappear
 * and edits reset.
 */
import { query } from '../db.js';
import { buildEventTemplate } from '../routes/events.js';

export const SHARED_GUEST_PROVIDER_ID = 'shared-demo';

function pad2(n) {
  return String(n).padStart(2, '0');
}

/** ISO date relative to today: daysAgo (0 = today). */
function daysAgo(n) {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  d.setDate(d.getDate() - n);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** ISO date in the future from today. */
function daysFromNow(n) {
  return daysAgo(-n);
}

function ceremonyMeta(name, date) {
  const n = String(name).toLowerCase();
  let theme = 'default';
  let quote = 'Celebrating this special moment with love, laughter, and joy.';
  if (n.includes('haldi')) {
    theme = 'haldi';
    quote = 'May turmeric bring you glow, joy, and a lifetime of blessings.';
  } else if (n.includes('mehend') || n.includes('mehndi')) {
    theme = 'mehendi';
    quote = 'Every leaf of mehendi is a wish for love that lasts forever.';
  } else if (n.includes('sangeet')) {
    theme = 'sangeet';
    quote = 'Dance like the music was written for your forever.';
  } else if (n.includes('tilak')) {
    theme = 'tilak';
    quote = 'A sacred mark of blessing as two families join in joy.';
  } else if (n.includes('engag')) {
    theme = 'engagement';
    quote = 'Two hearts, one promise, a beautiful lifetime ahead.';
  } else if (n.includes('nikah')) {
    theme = 'nikah';
    quote = 'May faith and love guide every step of your journey together.';
  } else if (n.includes('walima')) {
    theme = 'walima';
    quote = 'May this feast of joy mark the start of endless happiness.';
  } else if (n.includes('reception')) {
    theme = 'reception';
    quote = 'Celebrating love with the ones who matter most.';
  } else if (n.includes('wedding') || n.includes('main')) {
    theme = 'wedding';
    quote = 'Today we begin a beautiful forever, hand in hand.';
  }
  return { name, date: date || null, quote, theme };
}

/**
 * Create one demo event with todos + a few guests.
 */
async function insertDemoEvent(userId, def) {
  const {
    name,
    event_type,
    sub_type = null,
    event_date,
    end_date = null,
    location,
    budget,
    notes,
    answers = {},
    ceremonies = [],
    guests = [],
    status = 'planning',
  } = def;

  const ceremony_details = ceremonies.map((c) =>
    typeof c === 'string' ? ceremonyMeta(c, null) : ceremonyMeta(c.name, c.date)
  );
  const ceremonyNames = ceremony_details.map((d) => d.name);
  const metadata = {
    ...answers,
    days: answers.days || 1,
    guest_estimate: answers.guest_estimate || guests.reduce((s, g) => s + (g.count || 1), 0) || 50,
    ceremonies: ceremonyNames,
    ceremony_details,
  };

  const { rows } = await query(
    `INSERT INTO events (
       user_id, name, event_type, sub_type, event_date, end_date,
       location, budget, notes, metadata, status
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
    [
      userId,
      name,
      event_type,
      sub_type,
      event_date,
      end_date,
      location,
      budget,
      notes,
      JSON.stringify(metadata),
      status,
    ]
  );
  const event = rows[0];

  const template = buildEventTemplate(event_type, {
    ...answers,
    sub_type,
    wedding_style: sub_type || answers.wedding_style,
    ceremonies: ceremonyNames,
  });
  for (let i = 0; i < template.length; i++) {
    const t = template[i];
    const planned = Number(t.planned_amount) || 0;
    const token = i % 4 === 0 ? Math.round(planned * 0.2) : 0;
    const remaining = Math.max(planned - token, 0);
    await query(
      `INSERT INTO event_items
         (event_id, title, category, planned_amount, token_paid, remaining_amount, is_done, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [event.id, t.title, t.category, planned || 5000 + i * 1200, token, remaining || 5000 + i * 1200, i % 5 === 0, i]
    );
  }

  for (const g of guests) {
    await query(
      `INSERT INTO event_guests (event_id, name, side, ceremony, rsvp, count, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        event.id,
        g.name,
        g.side || 'Family',
        g.ceremony || ceremonyNames[0] || 'Main',
        g.rsvp || 'yes',
        g.count || 1,
        g.notes || 'Demo guest',
      ]
    );
  }

  return event;
}

async function seedDemoEvents(userId) {
  const weddingGuests = (ceremony) => [
    { name: 'Aarav Sharma', side: 'Groom', ceremony, rsvp: 'yes', count: 2 },
    { name: 'Diya Patel', side: 'Bride', ceremony, rsvp: 'yes', count: 3 },
    { name: 'Rohan Mehta', side: 'Friends', ceremony, rsvp: 'maybe', count: 1 },
    { name: 'Ananya Iyer', side: 'Bride', ceremony, rsvp: 'yes', count: 2 },
    { name: 'Kabir Khan', side: 'Groom', ceremony, rsvp: 'no', count: 1 },
  ];

  // Every app event type — plus multiple wedding styles
  const defs = [
    {
      name: 'Aarav & Diya Wedding',
      event_type: 'wedding',
      sub_type: 'Hindu',
      event_date: daysFromNow(45),
      end_date: daysFromNow(48),
      location: 'Jaipur Palace Resort',
      budget: 1500000,
      notes: 'Demo Hindu wedding with multi-day ceremonies',
      answers: {
        days: 4,
        guest_estimate: 350,
        bride_groom: 'Aarav & Diya',
        venue_budget: 400000,
        photo_budget: 120000,
        food_budget: 350000,
        wedding_style: 'Hindu',
      },
      ceremonies: [
        { name: 'Tilak', date: daysFromNow(40) },
        { name: 'Engagement', date: daysFromNow(42) },
        { name: 'Haldi', date: daysFromNow(45) },
        { name: 'Mehendi', date: daysFromNow(46) },
        { name: 'Sangeet', date: daysFromNow(46) },
        { name: 'Main Wedding', date: daysFromNow(47) },
        { name: 'Reception', date: daysFromNow(48) },
      ],
      guests: [
        ...weddingGuests('Main Wedding'),
        { name: 'Priya Nair', side: 'Bride', ceremony: 'Mehendi', rsvp: 'yes', count: 2 },
        { name: 'Vikram Joshi', side: 'Groom', ceremony: 'Sangeet', rsvp: 'yes', count: 2 },
      ],
    },
    {
      name: 'Sara & Imran Nikah',
      event_type: 'wedding',
      sub_type: 'Muslim / Nikah',
      event_date: daysFromNow(60),
      end_date: daysFromNow(61),
      location: 'Hyderabad Grand Ballroom',
      budget: 900000,
      notes: 'Demo Nikah + Walima',
      answers: {
        days: 2,
        guest_estimate: 280,
        wedding_style: 'Muslim / Nikah',
        venue_budget: 250000,
        food_budget: 300000,
      },
      ceremonies: [
        { name: 'Nikah', date: daysFromNow(60) },
        { name: 'Walima', date: daysFromNow(61) },
        { name: 'Reception', date: daysFromNow(61) },
      ],
      guests: weddingGuests('Nikah'),
    },
    {
      name: 'Rachel & John Church Wedding',
      event_type: 'wedding',
      sub_type: 'Christian',
      event_date: daysFromNow(90),
      location: 'St. Mary Church, Goa',
      budget: 750000,
      notes: 'Demo Christian wedding',
      answers: {
        days: 1,
        guest_estimate: 180,
        wedding_style: 'Christian',
        venue_budget: 200000,
      },
      ceremonies: [
        { name: 'Main Wedding', date: daysFromNow(90) },
        { name: 'Reception', date: daysFromNow(90) },
      ],
      guests: weddingGuests('Main Wedding'),
    },
    {
      name: 'Gurpreet & Simran Anand Karaj',
      event_type: 'wedding',
      sub_type: 'Sikh',
      event_date: daysFromNow(75),
      location: 'Amritsar Heritage Hall',
      budget: 1100000,
      notes: 'Demo Sikh wedding',
      answers: { days: 2, guest_estimate: 400, wedding_style: 'Sikh' },
      ceremonies: [
        { name: 'Engagement', date: daysFromNow(70) },
        { name: 'Main Wedding', date: daysFromNow(75) },
        { name: 'Reception', date: daysFromNow(75) },
      ],
      guests: weddingGuests('Main Wedding'),
    },
    {
      name: 'Maya & Alex Interfaith Wedding',
      event_type: 'wedding',
      sub_type: 'Interfaith',
      event_date: daysFromNow(100),
      location: 'Udaipur Lakeside',
      budget: 1300000,
      notes: 'Demo interfaith celebration',
      answers: { days: 3, guest_estimate: 220, wedding_style: 'Interfaith' },
      ceremonies: [
        { name: 'Engagement', date: daysFromNow(95) },
        { name: 'Main Wedding', date: daysFromNow(100) },
        { name: 'Reception', date: daysFromNow(101) },
      ],
      guests: weddingGuests('Main Wedding'),
    },
    {
      name: 'Court Marriage — Neha & Arjun',
      event_type: 'wedding',
      sub_type: 'Civil / Court',
      event_date: daysFromNow(30),
      location: 'City Civil Court + Rooftop Dinner',
      budget: 150000,
      notes: 'Demo civil wedding + dinner',
      answers: { days: 1, guest_estimate: 40, wedding_style: 'Civil / Court' },
      ceremonies: [
        { name: 'Main Wedding', date: daysFromNow(30) },
        { name: 'Reception', date: daysFromNow(30) },
      ],
      guests: weddingGuests('Reception'),
    },
    {
      name: 'Aanya 5th Birthday Bash',
      event_type: 'birthday',
      sub_type: 'Kids party',
      event_date: daysFromNow(18),
      location: 'Jump Zone, Pune',
      budget: 45000,
      notes: 'Demo kids birthday',
      answers: {
        days: 1,
        celebrant: 'Aanya',
        age: 5,
        theme: 'Kids party',
        guest_estimate: 35,
      },
      ceremonies: [{ name: 'Party', date: daysFromNow(18) }],
      guests: [
        { name: 'Kid guest A', side: 'School', ceremony: 'Party', rsvp: 'yes', count: 1 },
        { name: 'Kid guest B', side: 'Cousins', ceremony: 'Party', rsvp: 'yes', count: 2 },
        { name: 'Riya Aunt', side: 'Family', ceremony: 'Party', rsvp: 'maybe', count: 2 },
        { name: 'Uncle Sam', side: 'Family', ceremony: 'Party', rsvp: 'yes', count: 2 },
      ],
    },
    {
      name: 'Rohan Surprise 30th',
      event_type: 'birthday',
      sub_type: 'Surprise',
      event_date: daysFromNow(25),
      location: 'The Yellow Chilli, Delhi',
      budget: 60000,
      notes: 'Demo surprise birthday dinner',
      answers: {
        days: 1,
        celebrant: 'Rohan',
        age: 30,
        theme: 'Surprise',
        guest_estimate: 40,
      },
      ceremonies: [{ name: 'Dinner', date: daysFromNow(25) }],
      guests: [
        { name: 'Office friend 1', side: 'Friends', ceremony: 'Dinner', rsvp: 'yes', count: 1 },
        { name: 'Office friend 2', side: 'Friends', ceremony: 'Dinner', rsvp: 'yes', count: 1 },
        { name: 'College batch', side: 'Friends', ceremony: 'Dinner', rsvp: 'maybe', count: 4 },
      ],
    },
    {
      name: 'Silver Jubilee — Meera & Dev',
      event_type: 'anniversary',
      sub_type: '25 years',
      event_date: daysFromNow(55),
      location: 'Taj Vivanta, Bengaluru',
      budget: 200000,
      notes: 'Demo 25th anniversary',
      answers: {
        days: 1,
        years: 25,
        partner_names: 'Meera & Dev',
        guest_estimate: 80,
      },
      ceremonies: [{ name: 'Celebration', date: daysFromNow(55) }],
      guests: [
        { name: 'Family table 1', side: 'Family', ceremony: 'Celebration', rsvp: 'yes', count: 4 },
        { name: 'Family table 2', side: 'Family', ceremony: 'Celebration', rsvp: 'yes', count: 3 },
        { name: 'Neighbors', side: 'Friends', ceremony: 'Celebration', rsvp: 'maybe', count: 2 },
      ],
    },
    {
      name: '1st Anniversary Dinner',
      event_type: 'anniversary',
      sub_type: '1 year',
      event_date: daysFromNow(12),
      location: 'Olive Bar & Kitchen',
      budget: 25000,
      notes: 'Demo intimate anniversary',
      answers: { days: 1, years: 1, partner_names: 'Isha & Karan', guest_estimate: 2 },
      ceremonies: [{ name: 'Dinner', date: daysFromNow(12) }],
      guests: [
        { name: 'Isha', side: 'Couple', ceremony: 'Dinner', rsvp: 'yes', count: 1 },
        { name: 'Karan', side: 'Couple', ceremony: 'Dinner', rsvp: 'yes', count: 1 },
      ],
    },
    {
      name: 'New Home Gruhapravesh',
      event_type: 'housewarming',
      sub_type: 'Gruhapravesh',
      event_date: daysFromNow(22),
      location: 'Sector 62, Noida',
      budget: 80000,
      notes: 'Demo housewarming / pooja',
      answers: {
        days: 1,
        sub_type: 'Gruhapravesh',
        priority: 'Rituals',
        guest_estimate: 60,
      },
      ceremonies: [
        { name: 'Pooja', date: daysFromNow(22) },
        { name: 'Lunch', date: daysFromNow(22) },
      ],
      guests: [
        { name: 'Panditji', side: 'Rituals', ceremony: 'Pooja', rsvp: 'yes', count: 1 },
        { name: 'Parents', side: 'Family', ceremony: 'Pooja', rsvp: 'yes', count: 4 },
        { name: 'Colleagues', side: 'Friends', ceremony: 'Lunch', rsvp: 'maybe', count: 6 },
      ],
    },
    {
      name: 'Apartment Warming Party',
      event_type: 'housewarming',
      sub_type: 'Casual',
      event_date: daysFromNow(35),
      location: 'Whitefield, Bengaluru',
      budget: 40000,
      notes: 'Demo casual housewarming',
      answers: { days: 1, priority: 'Guest experience', guest_estimate: 45 },
      ceremonies: [{ name: 'Party', date: daysFromNow(35) }],
      guests: [
        { name: 'Building friends', side: 'Neighbors', ceremony: 'Party', rsvp: 'yes', count: 8 },
        { name: 'College friends', side: 'Friends', ceremony: 'Party', rsvp: 'yes', count: 5 },
      ],
    },
    {
      name: 'Q3 All-Hands Meet',
      event_type: 'corporate',
      sub_type: 'Town hall',
      event_date: daysFromNow(14),
      location: 'WeWork Galaxy, Mumbai',
      budget: 350000,
      notes: 'Demo corporate event',
      answers: {
        days: 1,
        sub_type: 'Company town hall',
        priority: 'Guest experience',
        guest_estimate: 200,
      },
      ceremonies: [
        { name: 'Keynote', date: daysFromNow(14) },
        { name: 'Networking', date: daysFromNow(14) },
      ],
      guests: [
        { name: 'Leadership', side: 'Internal', ceremony: 'Keynote', rsvp: 'yes', count: 12 },
        { name: 'Engineering', side: 'Internal', ceremony: 'Keynote', rsvp: 'yes', count: 40 },
        { name: 'Partners', side: 'External', ceremony: 'Networking', rsvp: 'maybe', count: 15 },
      ],
    },
    {
      name: 'Product Launch Evening',
      event_type: 'corporate',
      sub_type: 'Launch',
      event_date: daysFromNow(50),
      location: 'JW Marriott, Hyderabad',
      budget: 500000,
      notes: 'Demo product launch',
      answers: { days: 1, priority: 'Photography', guest_estimate: 150 },
      ceremonies: [
        { name: 'Demo', date: daysFromNow(50) },
        { name: 'Reception', date: daysFromNow(50) },
      ],
      guests: [
        { name: 'Press desk', side: 'Media', ceremony: 'Demo', rsvp: 'yes', count: 10 },
        { name: 'VIP clients', side: 'Clients', ceremony: 'Reception', rsvp: 'yes', count: 25 },
      ],
    },
    {
      name: 'Community Charity Gala',
      event_type: 'other',
      sub_type: 'Charity fundraiser',
      event_date: daysFromNow(40),
      location: 'City Convention Center',
      budget: 275000,
      notes: 'Demo custom / other event',
      answers: {
        days: 1,
        sub_type: 'Charity fundraiser',
        priority: 'Budget control',
        guest_estimate: 120,
      },
      ceremonies: [
        { name: 'Auction', date: daysFromNow(40) },
        { name: 'Dinner', date: daysFromNow(40) },
      ],
      guests: [
        { name: 'Sponsor A', side: 'Sponsors', ceremony: 'Dinner', rsvp: 'yes', count: 4 },
        { name: 'Volunteer team', side: 'Organizers', ceremony: 'Auction', rsvp: 'yes', count: 8 },
      ],
    },
    {
      name: 'College Reunion 2015 Batch',
      event_type: 'other',
      sub_type: 'Reunion',
      event_date: daysFromNow(70),
      location: 'Alumni Club, Chennai',
      budget: 90000,
      notes: 'Demo reunion event',
      answers: { days: 1, sub_type: 'College reunion', priority: 'Guest experience', guest_estimate: 90 },
      ceremonies: [{ name: 'Meetup', date: daysFromNow(70) }],
      guests: [
        { name: 'Batch coordinator', side: 'Organizers', ceremony: 'Meetup', rsvp: 'yes', count: 1 },
        { name: 'Hostel wing A', side: 'Alumni', ceremony: 'Meetup', rsvp: 'maybe', count: 12 },
      ],
    },
  ];

  for (const def of defs) {
    await insertDemoEvent(userId, def);
  }
}

const EXPENSE_CATS = ['Ecommerce', 'Grocery', 'Food', 'Travel', 'Electronics', 'Miscellaneous', 'Other'];
const SPEND_TYPES = ['Ecommerce', 'Grocery', 'Food', 'Travel', 'Electronics', 'Miscellaneous', 'Other'];
const CARDS = ['HDFC Millennia', 'SBI SimplyCLICK', 'ICICI Amazon Pay', 'Axis Ace', 'Amex SmartEarn'];
const BANKS = ['HDFC Bank', 'SBI', 'ICICI Bank', 'Axis Bank', 'Kotak', 'Bank of Baroda'];
const ASSET_TYPES = ['FD', 'RD', 'Mutual Funds', 'Stocks', 'Crypto', 'Gold', 'Silver', 'Saving Account', 'Other'];
const INCOME_SOURCES = [
  'Salary',
  'Freelance',
  'Interest',
  'Dividends',
  'Rental',
  'Bonus',
  'Side project',
  'Consulting',
  'Cashback',
  'Gift',
  'Refund',
  'Investment return',
  'Stipend',
  'Overtime',
  'Commission',
  'Royalty',
  'Tuition',
  'Affiliate',
  'Part-time',
  'Other income',
];
const PEOPLE = [
  'Aarav', 'Diya', 'Rohan', 'Ananya', 'Kabir', 'Isha', 'Vihaan', 'Meera',
  'Arjun', 'Sara', 'Dev', 'Nisha', 'Karan', 'Pooja', 'Amit', 'Riya',
  'Neha', 'Siddharth', 'Priya', 'Vikram', 'Tanvi', 'Harsh',
];
const LOAN_NAMES = [
  ['Home Loan', 'HDFC Bank'],
  ['Car Loan', 'SBI'],
  ['Personal Loan', 'ICICI Bank'],
  ['Education Loan', 'Axis Bank'],
  ['Two-wheeler Loan', 'Kotak'],
  ['Home Renovation', 'HDFC Bank'],
  ['Laptop Loan', 'SBI'],
  ['Travel Loan', 'ICICI Bank'],
  ['Medical Loan', 'Axis Bank'],
  ['Business Loan', 'Bank of Baroda'],
  ['Gold Loan', 'SBI'],
  ['Consumer Durable', 'HDFC Bank'],
  ['Wedding Loan', 'ICICI Bank'],
  ['Solar Loan', 'Axis Bank'],
  ['Furniture Loan', 'Kotak'],
  ['Phone EMI Loan', 'SBI'],
  ['Course Loan', 'HDFC Bank'],
  ['Bike Loan', 'ICICI Bank'],
  ['Appliance Loan', 'Axis Bank'],
  ['Top-up Home Loan', 'HDFC Bank'],
];
const EMI_PRODUCTS = [
  'iPhone 15', 'MacBook Air', 'Samsung TV', 'Sofa set', 'AC split',
  'Washing machine', 'Refrigerator', 'PlayStation 5', 'iPad Pro', 'AirPods Max',
  'Dining table', 'Office chair', 'Camera kit', 'Treadmill', 'Microwave',
  'Dishwasher', 'Water purifier', 'Induction hob', 'Smartwatch', 'Headphones',
];
const EXPENSE_ITEMS = [
  ['Amazon order', 'Ecommerce'],
  ['BigBasket veggies', 'Grocery'],
  ['Swiggy lunch', 'Food'],
  ['Uber to office', 'Travel'],
  ['USB-C hub', 'Electronics'],
  ['Netflix', 'Miscellaneous'],
  ['Pharmacy', 'Other'],
  ['Flipkart clothes', 'Ecommerce'],
  ['Milk & bread', 'Grocery'],
  ['Cafe coffee', 'Food'],
  ['Metro card', 'Travel'],
  ['Phone case', 'Electronics'],
  ['Haircut', 'Miscellaneous'],
  ['Donation', 'Other'],
  ['Myntra sale', 'Ecommerce'],
  ['Weekend groceries', 'Grocery'],
  ['Dinner out', 'Food'],
  ['Petrol fill', 'Travel'],
  ['Power bank', 'Electronics'],
  ['Gym snack', 'Miscellaneous'],
  ['Stationery', 'Other'],
  ['Book order', 'Ecommerce'],
  ['Fruits market', 'Grocery'],
  ['Team lunch', 'Food'],
  ['Airport cab', 'Travel'],
];

/**
 * Find or create the single shared guest demo account.
 */
export async function findOrCreateSharedGuestUser() {
  const { rows: existing } = await query(
    `SELECT * FROM users WHERE provider = 'guest' AND provider_id = $1 LIMIT 1`,
    [SHARED_GUEST_PROVIDER_ID]
  );
  if (existing[0]) return existing[0];

  const { rows } = await query(
    `INSERT INTO users (email, name, picture, provider, provider_id)
     VALUES ($1, $2, NULL, 'guest', $3) RETURNING *`,
    ['guest-demo@sanchiva.local', 'Guest User', SHARED_GUEST_PROVIDER_ID]
  );
  return rows[0];
}

/**
 * Remove all guest-owned rows (including events) then re-apply baseline seed.
 * Seed baseline is restored; session-only adds and edits are discarded.
 */
export async function resetGuestDemoData(userId) {
  // Child tables cascade via events, but wipe user-owned tables explicitly.
  await query('DELETE FROM daily_expenses WHERE user_id = $1', [userId]);
  await query('DELETE FROM loans WHERE user_id = $1', [userId]);
  await query('DELETE FROM credit_card_spends WHERE user_id = $1', [userId]);
  await query('DELETE FROM credit_card_emis WHERE user_id = $1', [userId]);
  await query('DELETE FROM income_sources WHERE user_id = $1', [userId]);
  await query('DELETE FROM assets WHERE user_id = $1', [userId]);
  await query('DELETE FROM money_given WHERE user_id = $1', [userId]);
  await query('DELETE FROM custom_categories WHERE user_id = $1', [userId]);
  // Events cascade items/guests; re-seed includes every event type.
  await query('DELETE FROM events WHERE user_id = $1', [userId]);
  await seedGuestDemoData(userId);
}

/**
 * Insert baseline demo data for every module (≥20 rows where listed; all event types).
 */
export async function seedGuestDemoData(userId) {
  // Daily expenses — 24 rows across categories
  for (let i = 0; i < 24; i++) {
    const [item, cat] = EXPENSE_ITEMS[i % EXPENSE_ITEMS.length];
    const amount = (120 + ((i * 37) % 2800) + (i % 5) * 15).toFixed(2);
    await query(
      `INSERT INTO daily_expenses (user_id, category, amount, expense_date, item_name)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, cat || EXPENSE_CATS[i % EXPENSE_CATS.length], amount, daysAgo(i % 45), `${item} #${i + 1}`]
    );
  }

  // Loans — 20
  const now = new Date();
  const cy = now.getFullYear();
  const cm = now.getMonth() + 1;
  for (let i = 0; i < 20; i++) {
    const [name, bank] = LOAN_NAMES[i % LOAN_NAMES.length];
    const startYear = cy - (1 + (i % 3));
    const startMonth = ((i * 3) % 12) + 1;
    const closeYear = cy + 1 + (i % 4);
    const closeMonth = ((i * 5) % 12) + 1;
    const emi = (2500 + i * 850 + (i % 4) * 200).toFixed(2);
    const status = i % 7 === 0 ? 'closed' : 'ongoing';
    await query(
      `INSERT INTO loans (
         user_id, bank_name, emi_deduction_bank, emi_deduction_date,
         emi_close_month, emi_close_year, emi_amount, status, start_month, start_year
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        userId,
        name,
        bank,
        ((i * 2) % 28) + 1,
        closeMonth,
        closeYear,
        emi,
        status,
        startMonth,
        startYear,
      ]
    );
  }

  // Credit card spends — 24
  for (let i = 0; i < 24; i++) {
    const amount = (200 + i * 175 + (i % 6) * 40).toFixed(2);
    await query(
      `INSERT INTO credit_card_spends (user_id, spend_date, spend_type, credit_card_name, amount)
       VALUES ($1,$2,$3,$4,$5)`,
      [
        userId,
        daysAgo(i % 40),
        SPEND_TYPES[i % SPEND_TYPES.length],
        CARDS[i % CARDS.length],
        amount,
      ]
    );
  }

  // Credit card EMIs — 20
  for (let i = 0; i < 20; i++) {
    const startYear = cy - (i % 2);
    const startMonth = ((i * 2) % 12) + 1;
    let endMonth = startMonth + 6 + (i % 6);
    let endYear = startYear;
    while (endMonth > 12) {
      endMonth -= 12;
      endYear += 1;
    }
    const amount = (999 + i * 220).toFixed(2);
    await query(
      `INSERT INTO credit_card_emis (
         user_id, emi_name, credit_card_name, start_month, start_year, end_month, end_year, amount
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [
        userId,
        EMI_PRODUCTS[i % EMI_PRODUCTS.length],
        CARDS[i % CARDS.length],
        startMonth,
        startYear,
        endMonth,
        endYear,
        amount,
      ]
    );
  }

  // Income sources — 24 (mix of current + previous months)
  for (let i = 0; i < 24; i++) {
    let month = cm - (i % 6);
    let year = cy;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    const amount = (8000 + i * 1500 + (i % 5) * 500).toFixed(2);
    await query(
      `INSERT INTO income_sources (user_id, source_name, amount, month, year)
       VALUES ($1,$2,$3,$4,$5)`,
      [userId, INCOME_SOURCES[i % INCOME_SOURCES.length], amount, month, year]
    );
  }

  // Assets — 20
  for (let i = 0; i < 20; i++) {
    const amount = (5000 + i * 12500 + (i % 3) * 2500).toFixed(2);
    await query(
      `INSERT INTO assets (user_id, asset_type, amount, notes)
       VALUES ($1,$2,$3,$4)`,
      [
        userId,
        ASSET_TYPES[i % ASSET_TYPES.length],
        amount,
        i % 2 === 0 ? 'Demo holding' : 'Long-term',
      ]
    );
  }

  // Money given — 20
  for (let i = 0; i < 20; i++) {
    const amount = (500 + i * 350 + (i % 4) * 100).toFixed(2);
    await query(
      `INSERT INTO money_given (user_id, person_name, given_date, amount, notes)
       VALUES ($1,$2,$3,$4,$5)`,
      [
        userId,
        PEOPLE[i % PEOPLE.length],
        daysAgo(10 + i * 3),
        amount,
        i % 3 === 0 ? 'Lent for trip' : 'Personal loan',
      ]
    );
  }

  // A few custom categories so dropdowns feel populated
  const customs = [
    ['expense', 'Subscriptions'],
    ['expense', 'Pets'],
    ['spend', 'Fuel'],
    ['spend', 'Utilities'],
    ['asset', 'PPF'],
    ['asset', 'NPS'],
  ];
  for (const [section, name] of customs) {
    try {
      await query(
        `INSERT INTO custom_categories (user_id, section, name) VALUES ($1, $2, $3)`,
        [userId, section, name]
      );
    } catch {
      /* ignore duplicates if unique index exists */
    }
  }

  // Events — every type (wedding styles + birthday, anniversary, housewarming, corporate, other)
  await seedDemoEvents(userId);
}

/**
 * Ensure shared guest exists with a clean baseline seed.
 * Always re-seeds so a new guest session never inherits another session's adds/edits
 * (e.g. previous guest closed the tab without logging out).
 */
export async function ensureGuestDemoReady() {
  const user = await findOrCreateSharedGuestUser();
  await resetGuestDemoData(user.id);
  return user;
}
