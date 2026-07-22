import 'dotenv/config';
import { ensureGuestDemoReady, resetGuestDemoData } from '../src/auth/guestSeed.js';
import { query } from '../src/db.js';

const user = await ensureGuestDemoReady();
console.log('guest user id', user.id, user.provider_id);

const tables = [
  'daily_expenses',
  'loans',
  'credit_card_spends',
  'credit_card_emis',
  'income_sources',
  'assets',
  'money_given',
  'events',
];
for (const t of tables) {
  const { rows } = await query(`SELECT COUNT(*)::int AS c FROM ${t} WHERE user_id = $1`, [user.id]);
  console.log(`${t}: ${rows[0].c}`);
}

await query(
  `INSERT INTO daily_expenses (user_id, category, amount, expense_date, item_name)
   VALUES ($1,'Food',99,'2026-01-01','Guest add')`,
  [user.id]
);
const before = await query('SELECT COUNT(*)::int AS c FROM daily_expenses WHERE user_id = $1', [user.id]);
console.log('after add expenses:', before.rows[0].c);

await resetGuestDemoData(user.id);
const after = await query('SELECT COUNT(*)::int AS c FROM daily_expenses WHERE user_id = $1', [user.id]);
console.log('after reset expenses:', after.rows[0].c);
const guestAdd = await query(
  `SELECT COUNT(*)::int AS c FROM daily_expenses WHERE user_id = $1 AND item_name = 'Guest add'`,
  [user.id]
);
console.log('guest add remaining:', guestAdd.rows[0].c);
process.exit(0);
