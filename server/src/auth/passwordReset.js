import crypto from 'crypto';
import { query } from '../db.js';
import { hashPassword } from './tokens.js';
import { sendMail } from './sendMail.js';
import { buildOtpEmail, resolveLogoPath } from './otpEmail.js';

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

export async function ensurePasswordResetTable() {
  await query(`
    CREATE TABLE IF NOT EXISTS password_reset_otps (
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
    CREATE INDEX IF NOT EXISTS password_reset_otps_email_idx
    ON password_reset_otps (LOWER(email), created_at DESC)
  `);
}

async function findLocalUserByEmail(emailNorm) {
  const { rows } = await query(
    `SELECT id, email, name, provider FROM users
     WHERE provider = 'local' AND LOWER(email) = $1 LIMIT 1`,
    [emailNorm]
  );
  return rows[0] || null;
}

async function sendResetEmail({ email, otp, name }) {
  const appUrl = (process.env.APP_URL || 'https://sanchivaorg.duckdns.org').replace(/\/$/, '');
  const hasLogoFile = !!resolveLogoPath();
  const { subject, html, text } = buildOtpEmail({
    otp,
    purpose: 'reset',
    name,
    logoSrc: hasLogoFile ? 'cid:sanchiva-logo' : `${appUrl}/sanchiva-logo.png`,
  });

  const result = await sendMail({ to: email, subject, text, html, embedLogo: hasLogoFile });
  if (!result.delivered) {
    console.log(`[password-reset] OTP for ${email}: ${otp}`);
  }
  return result;
}

/**
 * Start reset for a local email/password account.
 * Invalid emails and unknown addresses return an error and never create an OTP.
 * May include debug_otp when email is not configured / non-prod.
 */
export async function requestPasswordReset(email) {
  await ensurePasswordResetTable();
  const emailNorm = normEmail(email);
  if (!emailNorm || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
    const err = new Error('Enter a valid email address');
    err.status = 400;
    throw err;
  }

  const user = await findLocalUserByEmail(emailNorm);
  if (!user) {
    const { rows: google } = await query(
      `SELECT id FROM users WHERE LOWER(email) = $1 AND provider = 'google' LIMIT 1`,
      [emailNorm]
    );
    if (google[0]) {
      const err = new Error('This email uses Google sign-in. Please continue with Google.');
      err.status = 400;
      throw err;
    }
    const err = new Error('No account found for this email. Check the address or create an account.');
    err.status = 404;
    throw err;
  }

  const otp = generateOtp();
  const code_hash = hashOtp(otp);
  const expires_at = new Date(Date.now() + OTP_TTL_MS);

  // Invalidate previous unused codes for this email
  await query(
    `UPDATE password_reset_otps SET consumed = TRUE
     WHERE LOWER(email) = $1 AND consumed = FALSE`,
    [emailNorm]
  );

  await query(
    `INSERT INTO password_reset_otps (email, code_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [emailNorm, code_hash, expires_at.toISOString()]
  );

  let delivered = false;
  try {
    const send = await sendResetEmail({ email: emailNorm, otp, name: user.name });
    delivered = !!send.delivered;
  } catch (e) {
    console.error('[password-reset] send failed:', e.message);
    // Still allow debug path when mail fails in non-production
  }

  const out = {
    message: 'Reset code sent. Check your email.',
    email: emailNorm,
    delivered,
  };
  const allowDebug =
    process.env.PASSWORD_RESET_RETURN_OTP === '1' ||
    process.env.NODE_ENV !== 'production' ||
    !delivered;
  if (allowDebug) {
    out.debug_otp = otp;
  }
  return out;
}

export async function verifyPasswordResetOtp(email, otp) {
  await ensurePasswordResetTable();
  const emailNorm = normEmail(email);
  const code = String(otp || '').trim();
  if (!emailNorm || !/^\d{6}$/.test(code)) {
    const err = new Error('Enter the 6-digit code from your email');
    err.status = 400;
    throw err;
  }

  const user = await findLocalUserByEmail(emailNorm);
  if (!user) {
    const err = new Error('Invalid or expired code');
    err.status = 400;
    throw err;
  }

  const { rows } = await query(
    `SELECT * FROM password_reset_otps
     WHERE LOWER(email) = $1 AND consumed = FALSE
     ORDER BY created_at DESC LIMIT 1`,
    [emailNorm]
  );
  const row = rows[0];
  if (!row) {
    const err = new Error('Invalid or expired code');
    err.status = 400;
    throw err;
  }
  if (new Date(row.expires_at).getTime() < Date.now()) {
    await query(`UPDATE password_reset_otps SET consumed = TRUE WHERE id = $1`, [row.id]);
    const err = new Error('This code has expired. Request a new one.');
    err.status = 400;
    throw err;
  }
  if (Number(row.attempts) >= MAX_ATTEMPTS) {
    await query(`UPDATE password_reset_otps SET consumed = TRUE WHERE id = $1`, [row.id]);
    const err = new Error('Too many attempts. Request a new code.');
    err.status = 400;
    throw err;
  }

  const ok = row.code_hash === hashOtp(code);
  if (!ok) {
    await query(`UPDATE password_reset_otps SET attempts = attempts + 1 WHERE id = $1`, [row.id]);
    const err = new Error('Invalid or expired code');
    err.status = 400;
    throw err;
  }

  return { ok: true, email: emailNorm };
}

export async function resetPasswordWithOtp({ email, otp, password, confirmPassword }) {
  await verifyPasswordResetOtp(email, otp);

  if (confirmPassword != null && String(password) !== String(confirmPassword)) {
    const err = new Error('Password and confirm password do not match');
    err.status = 400;
    throw err;
  }
  if (!password || String(password).length < 8) {
    const err = new Error('Password must be at least 8 characters');
    err.status = 400;
    throw err;
  }

  const emailNorm = normEmail(email);
  const user = await findLocalUserByEmail(emailNorm);
  if (!user) {
    const err = new Error('Could not reset password for this account');
    err.status = 400;
    throw err;
  }

  const password_hash = await hashPassword(password);
  await query(`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`, [
    password_hash,
    user.id,
  ]);

  await query(
    `UPDATE password_reset_otps SET consumed = TRUE
     WHERE LOWER(email) = $1 AND consumed = FALSE`,
    [emailNorm]
  );

  return { message: 'Password updated. You can log in with your new password.' };
}
