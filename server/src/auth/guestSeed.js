/**
 * Guest demo data: shared guest account gets rich sample rows in every
 * module except Events. On logout we wipe session changes and re-seed so
 * the baseline always returns; guest-added rows disappear and edits reset.
 */
import { query } from '../db.js';

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
  // Events intentionally not seeded; still clear any guest-created events.
  await query('DELETE FROM events WHERE user_id = $1', [userId]);
  await seedGuestDemoData(userId);
}

/**
 * Insert baseline demo data for every module except Events (≥20 rows each).
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
