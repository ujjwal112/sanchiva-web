/**
 * Upgrades existing databases for multi-user auth.
 * Runs AFTER schema.sql CREATE IF NOT EXISTS.
 */
import { query } from './db.js';

async function tableExists(table) {
  const { rows } = await query(
    `SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = $1`,
    [table]
  );
  return rows.length > 0;
}

async function columnExists(table, column) {
  const { rows } = await query(
    `SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
    [table, column]
  );
  return rows.length > 0;
}

async function addUserIdIfMissing(table) {
  if (!(await tableExists(table))) return;
  if (await columnExists(table, 'user_id')) {
    console.log(`  · ${table}.user_id already exists`);
    return;
  }
  await query(
    `ALTER TABLE ${table}
     ADD COLUMN user_id INTEGER REFERENCES users(id) ON DELETE CASCADE`
  );
  console.log(`  + ${table}.user_id`);
}

export async function runMigrations() {
  console.log('Running migrations…');

  // Ensure auth tables exist even if schema.sql was an older version mid-deploy
  await query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL,
      name VARCHAR(255) NOT NULL DEFAULT '',
      picture TEXT,
      provider VARCHAR(50) NOT NULL,
      provider_id VARCHAR(255) NOT NULL,
      password_hash TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(provider, provider_id)
    )
  `);
  await query(`
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash VARCHAR(128) NOT NULL UNIQUE,
      expires_at TIMESTAMPTZ NOT NULL,
      revoked BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  const tables = [
    'custom_categories',
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
    try {
      await addUserIdIfMissing(t);
    } catch (e) {
      console.warn(`  ! ${t}: ${e.message}`);
      throw e;
    }
  }

  // Ceremony-wise guest lists
  if (await tableExists('event_guests') && !(await columnExists('event_guests', 'ceremony'))) {
    await query(
      `ALTER TABLE event_guests ADD COLUMN ceremony VARCHAR(150) DEFAULT 'General'`
    );
    console.log('  + event_guests.ceremony');
  }

  // Local email/password accounts
  if (await tableExists('users') && !(await columnExists('users', 'password_hash'))) {
    await query(`ALTER TABLE users ADD COLUMN password_hash TEXT`);
    console.log('  + users.password_hash');
  }
  try {
    await query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_local_email_lower
      ON users (LOWER(email))
      WHERE provider = 'local'
    `);
  } catch (e) {
    console.warn('  ! users local email index:', e.message);
  }

  // Drop legacy single-tenant unique constraint if present
  try {
    await query(`ALTER TABLE custom_categories DROP CONSTRAINT IF EXISTS custom_categories_section_name_key`);
  } catch (_) {
    /* ignore */
  }

  // Multi-user unique category names
  try {
    await query(`
      CREATE UNIQUE INDEX IF NOT EXISTS custom_categories_user_section_name
      ON custom_categories (user_id, section, name)
      WHERE user_id IS NOT NULL
    `);
  } catch (e) {
    console.warn('  ! custom_categories unique index:', e.message);
  }

  // ROI (rate of interest %) on loans and card EMIs
  if (await tableExists('loans') && !(await columnExists('loans', 'roi'))) {
    await query(
      `ALTER TABLE loans
       ADD COLUMN roi NUMERIC(7, 3) NOT NULL DEFAULT 0 CHECK (roi >= 0)`
    );
    console.log('  + loans.roi');
  }
  if (await tableExists('credit_card_emis') && !(await columnExists('credit_card_emis', 'roi'))) {
    await query(
      `ALTER TABLE credit_card_emis
       ADD COLUMN roi NUMERIC(7, 3) NOT NULL DEFAULT 0 CHECK (roi >= 0)`
    );
    console.log('  + credit_card_emis.roi');
  }

  // Daily expense payment method (Paid via)
  if (await tableExists('daily_expenses') && !(await columnExists('daily_expenses', 'paid_via'))) {
    await query(
      `ALTER TABLE daily_expenses
       ADD COLUMN paid_via VARCHAR(50) NOT NULL DEFAULT 'Cash'`
    );
    console.log('  + daily_expenses.paid_via');
  }
  if (await tableExists('daily_expenses') && !(await columnExists('daily_expenses', 'paid_via_detail'))) {
    await query(
      `ALTER TABLE daily_expenses
       ADD COLUMN paid_via_detail VARCHAR(150) NOT NULL DEFAULT ''`
    );
    console.log('  + daily_expenses.paid_via_detail');
  }

  // Splits tables (shared expenses)
  await query(`
    CREATE TABLE IF NOT EXISTS split_groups (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      name VARCHAR(150) NOT NULL,
      notes VARCHAR(255),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  await query(`
    CREATE TABLE IF NOT EXISTS split_members (
      id SERIAL PRIMARY KEY,
      group_id INTEGER NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
      name VARCHAR(150) NOT NULL,
      is_you BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  await query(`
    CREATE TABLE IF NOT EXISTS split_expenses (
      id SERIAL PRIMARY KEY,
      group_id INTEGER NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
      description VARCHAR(255) NOT NULL,
      amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
      paid_by_member_id INTEGER NOT NULL REFERENCES split_members(id),
      expense_date DATE NOT NULL,
      notes VARCHAR(255),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  await query(`
    CREATE TABLE IF NOT EXISTS split_shares (
      id SERIAL PRIMARY KEY,
      expense_id INTEGER NOT NULL REFERENCES split_expenses(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES split_members(id) ON DELETE CASCADE,
      share_amount NUMERIC(12, 2) NOT NULL CHECK (share_amount >= 0),
      UNIQUE(expense_id, member_id)
    )
  `);
  await query(`
    CREATE TABLE IF NOT EXISTS split_settlements (
      id SERIAL PRIMARY KEY,
      group_id INTEGER NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
      from_member_id INTEGER NOT NULL REFERENCES split_members(id),
      to_member_id INTEGER NOT NULL REFERENCES split_members(id),
      amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
      settled_date DATE NOT NULL,
      notes VARCHAR(255),
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  console.log('  · split_* tables ready');

  // Indexes that require user_id, only after column exists
  const indexes = [
    `CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_daily_expenses_user_date ON daily_expenses(user_id, expense_date)`,
    `CREATE INDEX IF NOT EXISTS idx_loans_user ON loans(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_cc_spends_user ON credit_card_spends(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_income_user ON income_sources(user_id, year, month)`,
    `CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_event_items_event ON event_items(event_id)`,
    `CREATE INDEX IF NOT EXISTS idx_event_guests_event ON event_guests(event_id)`,
    `CREATE INDEX IF NOT EXISTS idx_split_groups_user ON split_groups(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_split_members_group ON split_members(group_id)`,
    `CREATE INDEX IF NOT EXISTS idx_split_expenses_group ON split_expenses(group_id)`,
    `CREATE INDEX IF NOT EXISTS idx_split_shares_expense ON split_shares(expense_id)`,
    `CREATE INDEX IF NOT EXISTS idx_split_settlements_group ON split_settlements(group_id)`,
  ];

  for (const sql of indexes) {
    try {
      await query(sql);
    } catch (e) {
      console.warn('  ! index:', e.message);
    }
  }

  console.log('Migrations done');
}
