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

// PGSSL=false forces no SSL (Docker Postgres on same host/network).
// Otherwise enable SSL for managed clouds or when PGSSL=true / production.
const pgSslEnv = String(process.env.PGSSL || '').toLowerCase();
const forceNoSsl = pgSslEnv === 'false' || pgSslEnv === '0' || pgSslEnv === 'off';
const forceSsl = pgSslEnv === 'true' || pgSslEnv === '1' || pgSslEnv === 'on';
const cloudDb =
  connectionString &&
  /render\.com|neon\.tech|supabase\.co|pooler\.supabase\.com|amazonaws\.com|azure\.com/i.test(
    connectionString
  );
const needsSsl = !forceNoSsl && (forceSsl || cloudDb || process.env.NODE_ENV === 'production');

const poolConfig = connectionString
  ? {
      connectionString,
      ssl: needsSsl ? { rejectUnauthorized: false } : false,
    }
  : {
      host: process.env.PGHOST || 'localhost',
      port: Number(process.env.PGPORT || 5432),
      user: process.env.PGUSER || 'expense_user',
      password: process.env.PGPASSWORD || 'expense_pass',
      database: process.env.PGDATABASE || 'expense_tracker',
      ssl: forceSsl ? { rejectUnauthorized: false } : false,
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
