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
