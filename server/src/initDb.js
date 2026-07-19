import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from './db.js';
import { runMigrations } from './migrate.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function init() {
  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');
  try {
    await pool.query(sql);
    console.log('✓ Database schema applied');
    await runMigrations();
    console.log('✓ Database ready');
  } catch (err) {
    console.error('Failed to init database:', err.message);
    console.error('\nMake sure PostgreSQL is running and DATABASE_URL is correct.');
    process.exit(1);
  } finally {
    await pool.end();
  }
}

init();
