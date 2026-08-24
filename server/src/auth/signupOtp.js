import crypto from 'crypto';
import { query } from '../db.js';
import { lookupEmailForSignup } from './tokens.js';
import { sendMail } from './sendMail.js';
import { buildOtpEmail } from './otpEmail.js';

const OTP_TTL_MS = 15 * 60 * 1000; // 15 minutes
const MAX_ATTEMPTS = 5;

function normEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

function generateOtp() {
  return String(crypto.randomInt(100000, 999999));
}

function hashOtp(otp) {
  return crypto.createHash('sha256').update(String(otp)).digest('hex');
}

export async function ensureSignupOtpTable() {
  await query(`
    CREATE TABLE IF NOT EXISTS signup_otps (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL,
      code_hash VARCHAR(128) NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      consumed BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  await query(`
    CREATE INDEX IF NOT EXISTS signup_otps_email_idx
    ON signup_otps (LOWER(email), created_at DESC)
  `);
}

async function sendSignupEmail({ email, otp }) {
  const appUrl = (process.env.APP_URL || 'https://sanchivaorg.duckdns.org').replace(/\/$/, '');
  const { subject, html, text } = buildOtpEmail({
    otp,
    purpose: 'signup',
    logoSrc: `${appUrl}/sanchiva-logo.png`,
  });

  const result = await sendMail({ to: email, subject, text, html, embedLogo: false });
  if (!result.delivered) {
    console.log(`[signup-otp] OTP for ${email}: ${otp}`);
  }
  return result;
}

/**
 * Send a signup verification code. Email must not already be registered.
 * May include debug_otp when email is not configured / non-prod.
 */
export async function requestSignupOtp(email) {
  await ensureSignupOtpTable();
  const emailNorm = normEmail(email);
  if (!emailNorm || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
    const err = new Error('Enter a valid email address');
    err.status = 400;
    throw err;
  }

  const lookup = await lookupEmailForSignup(emailNorm);
  if (lookup.exists) {
    if (lookup.provider === 'google') {
      const err = new Error(
        'This email is already registered with Google. Please use Continue with Google to sign in.'
      );
      err.status = 409;
      throw err;
    }
    const err = new Error('An account with this email already exists. Please log in.');
    err.status = 409;
    throw err;
  }

  const otp = generateOtp();
  const code_hash = hashOtp(otp);
  const expires_at = new Date(Date.now() + OTP_TTL_MS);

  await query(
    `UPDATE signup_otps SET consumed = TRUE
     WHERE LOWER(email) = $1 AND consumed = FALSE`,
    [emailNorm]
  );

  await query(
    `INSERT INTO signup_otps (email, code_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [emailNorm, code_hash, expires_at.toISOString()]
  );

  let delivered = false;
  try {
    const send = await sendSignupEmail({ email: emailNorm, otp });
    delivered = !!send.delivered;
  } catch (e) {
    console.error('[signup-otp] send failed:', e.message);
    // Do not pretend success when mail failed — consume this OTP so it cannot be used blindly.
    await query(
      `UPDATE signup_otps SET consumed = TRUE
       WHERE LOWER(email) = $1 AND consumed = FALSE`,
      [emailNorm]
    );
    const err = new Error('Could not send the verification email. Please try again in a moment.');
    err.status = 502;
    throw err;
  }

  if (!delivered) {
    console.log(`[signup-otp] OTP for ${emailNorm}: ${otp} (mail not delivered)`);
  }

  const out = {
    message: 'Verification code sent. Check your email (and spam folder).',
    email: emailNorm,
    delivered,
  };
  const allowDebug =
    process.env.SIGNUP_OTP_RETURN_OTP === '1' ||
    process.env.PASSWORD_RESET_RETURN_OTP === '1' ||
    process.env.NODE_ENV !== 'production' ||
    !delivered;
  if (allowDebug) {
    out.debug_otp = otp;
  }
  return out;
}

/**
 * Verify signup OTP without consuming it (so register can consume after user create).
 */
export async function verifySignupOtp(email, otp) {
  await ensureSignupOtpTable();
  const emailNorm = normEmail(email);
  const code = String(otp || '').trim();
  if (!emailNorm || !/^\d{6}$/.test(code)) {
    const err = new Error('Enter the 6-digit code from your email');
    err.status = 400;
    throw err;
  }

  const lookup = await lookupEmailForSignup(emailNorm);
  if (lookup.exists) {
    const err = new Error('An account with this email already exists. Please log in.');
    err.status = 409;
    throw err;
  }

  const row = await findActiveSignupOtp(emailNorm);
  await assertOtpValid(row, code);

  return { ok: true, email: emailNorm };
}

async function findActiveSignupOtp(emailNorm) {
  const { rows } = await query(
    `SELECT * FROM signup_otps
     WHERE LOWER(email) = $1 AND consumed = FALSE
     ORDER BY created_at DESC LIMIT 1`,
    [emailNorm]
  );
  return rows[0] || null;
}

async function assertOtpValid(row, code) {
  if (!row) {
    const err = new Error('Invalid or expired code');
    err.status = 400;
    throw err;
  }
  if (new Date(row.expires_at).getTime() < Date.now()) {
    await query(`UPDATE signup_otps SET consumed = TRUE WHERE id = $1`, [row.id]);
    const err = new Error('This code has expired. Request a new one.');
    err.status = 400;
    throw err;
  }
  if (Number(row.attempts) >= MAX_ATTEMPTS) {
    await query(`UPDATE signup_otps SET consumed = TRUE WHERE id = $1`, [row.id]);
    const err = new Error('Too many attempts. Request a new code.');
    err.status = 400;
    throw err;
  }

  const ok = row.code_hash === hashOtp(code);
  if (!ok) {
    await query(`UPDATE signup_otps SET attempts = attempts + 1 WHERE id = $1`, [row.id]);
    const err = new Error('Invalid or expired code');
    err.status = 400;
    throw err;
  }
  return true;
}

/**
 * Mark a valid signup OTP consumed. Call AFTER the user row is created —
 * does not require the email to still be free.
 */
export async function consumeSignupOtp(email, otp) {
  await ensureSignupOtpTable();
  const emailNorm = normEmail(email);
  const code = String(otp || '').trim();
  if (!emailNorm || !/^\d{6}$/.test(code)) {
    const err = new Error('Enter the 6-digit code from your email');
    err.status = 400;
    throw err;
  }

  const row = await findActiveSignupOtp(emailNorm);
  await assertOtpValid(row, code);
  await query(`UPDATE signup_otps SET consumed = TRUE WHERE id = $1`, [row.id]);
  return { ok: true, email: emailNorm };
}
