/**
 * Safe migrations for existing deployments (add users + user_id columns).
 * Runs after schema.sql CREATE IF NOT EXISTS.
 */
import { query } from './db.js';

async function columnExists(table, column) {
  const { rows } = await query(
    `SELECT 1 FROM information_schema.columns
     WHERE table_name = $1 AND column_name = $2`,
    [table, column]
  );
  return rows.length > 0;
}

async function addUserIdIfMissing(table) {
  if (await columnExists(table, 'user_id')) return;
  // nullable first for legacy rows, then we leave legacy orphaned (not visible)
  await query(`ALTER TABLE ${table} ADD COLUMN user_id INTEGER REFERENCES users(id) ON DELETE CASCADE`);
  console.log(`  + ${table}.user_id`);
}

export async function runMigrations() {
  console.log('Running migrations…');

  // Ensure users / refresh_tokens exist (also in schema.sql)
  await query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL,
      name VARCHAR(255) NOT NULL DEFAULT '',
      picture TEXT,
      provider VARCHAR(50) NOT NULL,
      provider_id VARCHAR(255) NOT NULL,
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
      console.warn(`  skip ${t}:`, e.message);
    }
  }

  // Fix custom_categories unique for multi-user
  try {
    await query(`ALTER TABLE custom_categories DROP CONSTRAINT IF EXISTS custom_categories_section_name_key`);
  } catch (_) {
    /* ignore */
  }
  try {
    await query(`
      CREATE UNIQUE INDEX IF NOT EXISTS custom_categories_user_section_name
      ON custom_categories(user_id, section, name)
    `);
  } catch (_) {
    /* ignore */
  }

  console.log('Migrations done');
}
