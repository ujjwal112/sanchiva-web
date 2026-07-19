import pg from 'pg';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { Pool, types } = pg;

// Return DATE / TIMESTAMP as plain strings to avoid timezone day-shifts in the UI
types.setTypeParser(1082, (val) => val); // date
types.setTypeParser(1114, (val) => val); // timestamp without time zone
types.setTypeParser(1184, (val) => val); // timestamptz

const connectionString = process.env.DATABASE_URL;
const needsSsl =
  process.env.PGSSL === 'true' ||
  process.env.NODE_ENV === 'production' ||
  (connectionString &&
    /render\.com|neon\.tech|supabase\.co|amazonaws\.com|azure\.com/i.test(connectionString));

const poolConfig = connectionString
  ? {
      connectionString,
      ssl: needsSsl ? { rejectUnauthorized: false } : undefined,
    }
  : {
      host: process.env.PGHOST || 'localhost',
      port: Number(process.env.PGPORT || 5432),
      user: process.env.PGUSER || 'expense_user',
      password: process.env.PGPASSWORD || 'expense_pass',
      database: process.env.PGDATABASE || 'expense_tracker',
    };

const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL pool error', err);
});

export async function query(text, params) {
  return pool.query(text, params);
}

export async function getClient() {
  return pool.connect();
}

export default pool;
