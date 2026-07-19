import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function init() {
  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');
  try {
    await pool.query(sql);
    console.log('✓ Database schema applied successfully');
  } catch (err) {
    console.error('Failed to init database:', err.message);
    console.error('\nMake sure PostgreSQL is running and credentials in server/.env are correct.');
    console.error('Quick start: docker compose up -d');
    process.exit(1);
  } finally {
    await pool.end();
  }
}

init();
