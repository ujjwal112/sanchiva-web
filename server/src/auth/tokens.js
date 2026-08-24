import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { query } from '../db.js';
import {
  ensureGuestDemoReady,
  resetGuestDemoData,
  SHARED_GUEST_PROVIDER_ID,
} from './guestSeed.js';

const BCRYPT_ROUNDS = 12;

// Long-lived sessions: stay signed in until the user logs out (mobile + web).
// Override with JWT_ACCESS_TTL / JWT_REFRESH_DAYS in env if needed.
const ACCESS_TTL = process.env.JWT_ACCESS_TTL || '30d';
const REFRESH_TTL_DAYS = Number(process.env.JWT_REFRESH_DAYS || 3650);

function secrets() {
  const access = process.env.JWT_ACCESS_SECRET || 'sanchiva-dev-access-secret-change-me';
  const refresh = process.env.JWT_REFRESH_SECRET || 'sanchiva-dev-refresh-secret-change-me';
  return { access, refresh };
}

export function signAccessToken(user) {
  const { access } = secrets();
  return jwt.sign(
    {
      sub: Number(user.id),
      email: user.email,
      name: user.name,
      picture: user.picture,
      provider: user.provider,
      type: 'access',
    },
    access,
    { expiresIn: ACCESS_TTL }
  );
}

export function verifyAccessToken(token) {
  const { access } = secrets();
  return jwt.verify(token, access);
}

export async function issueRefreshToken(userId) {
  const raw = crypto.randomBytes(48).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(raw).digest('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [userId, tokenHash, expiresAt]
  );
  return raw;
}

export async function rotateRefreshToken(oldRaw) {
  const oldHash = crypto.createHash('sha256').update(oldRaw).digest('hex');
  const { rows } = await query(
    `SELECT * FROM refresh_tokens
     WHERE token_hash = $1 AND revoked = FALSE AND expires_at > NOW()`,
    [oldHash]
  );
  if (!rows[0]) return null;
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE id = $1`, [rows[0].id]);
  const newRaw = await issueRefreshToken(rows[0].user_id);
  return { userId: rows[0].user_id, refreshToken: newRaw };
}

export async function revokeRefreshToken(raw) {
  if (!raw) return;
  const hash = crypto.createHash('sha256').update(raw).digest('hex');
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE token_hash = $1`, [hash]);
}

export async function revokeAllUserTokens(userId) {
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, [userId]);
}

/**
 * One email may only use one auth method (local XOR google/microsoft/facebook).
 * Blocks Google login when a password account already exists for that email, and
 * blocks creating a new OAuth user when any other provider owns the email.
 */
async function assertEmailExclusiveToProvider(emailNorm, intendedProvider) {
  if (!emailNorm) return;
  const { rows } = await query(
    `SELECT provider FROM users
     WHERE LOWER(email) = $1
       AND provider <> 'guest'
       AND provider <> $2
     ORDER BY CASE provider
       WHEN 'local' THEN 0
       WHEN 'google' THEN 1
       WHEN 'microsoft' THEN 2
       WHEN 'facebook' THEN 3
       ELSE 9
     END
     LIMIT 1`,
    [emailNorm, intendedProvider]
  );
  const other = rows[0]?.provider;
  if (!other) return;

  if (intendedProvider === 'local') {
    if (other === 'google') {
      const err = new Error(
        'This email is already registered with Google. Please use Continue with Google to sign in.'
      );
      err.status = 409;
      throw err;
    }
    const err = new Error(
      `This email is already registered with ${other}. Please use that sign-in method.`
    );
    err.status = 409;
    throw err;
  }

  // OAuth attempting to use an email that already has another method (usually local)
  if (other === 'local') {
    const err = new Error(
      'This email already has a Sanchiva password account. Please log in with email and password.'
    );
    err.status = 409;
    throw err;
  }
  const err = new Error(
    `This email is already registered with ${other}. Please use that sign-in method.`
  );
  err.status = 409;
  throw err;
}

export async function findOrCreateOAuthUser({ provider, providerId, email, name, picture }) {
  const emailNorm = String(email || '')
    .trim()
    .toLowerCase();

  // Always enforce one-email-one-method, even for returning OAuth users
  // (covers cases where a password account was created for the same email later).
  await assertEmailExclusiveToProvider(emailNorm, provider);

  const { rows: existing } = await query(
    `SELECT * FROM users WHERE provider = $1 AND provider_id = $2`,
    [provider, providerId]
  );
  if (existing[0]) {
    const { rows } = await query(
      `UPDATE users SET name = $1, picture = $2, email = $3, updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [name || existing[0].name, picture || existing[0].picture, email || existing[0].email, existing[0].id]
    );
    return rows[0];
  }

  const { rows } = await query(
    `INSERT INTO users (email, name, picture, provider, provider_id)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [emailNorm || `${providerId}@${provider}.oauth`, name || 'User', picture || null, provider, providerId]
  );
  return rows[0];
}

export async function getUserById(id) {
  const uid = Number(id);
  if (!uid || Number.isNaN(uid)) return null;
  const { rows } = await query(
    `SELECT id, email, name, picture, provider, provider_id, created_at FROM users WHERE id = $1`,
    [uid]
  );
  return rows[0] || null;
}

export function publicUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    picture: user.picture || null,
    provider: user.provider,
    created_at: user.created_at,
  };
}

export async function hashPassword(password) {
  return bcrypt.hash(String(password), BCRYPT_ROUNDS);
}

export async function verifyPassword(password, passwordHash) {
  if (!passwordHash) return false;
  return bcrypt.compare(String(password), passwordHash);
}

/** Update display name for a local (email/password) account only. */
export async function updateLocalUserName(userId, name) {
  const uid = Number(userId);
  const displayName = String(name || '').trim();
  if (!uid || Number.isNaN(uid)) {
    const err = new Error('Not signed in');
    err.status = 401;
    throw err;
  }
  if (!displayName) {
    const err = new Error('Enter your name');
    err.status = 400;
    throw err;
  }
  if (displayName.length > 80) {
    const err = new Error('Name is too long');
    err.status = 400;
    throw err;
  }

  const { rows: found } = await query(
    `SELECT id, provider FROM users WHERE id = $1 LIMIT 1`,
    [uid]
  );
  const user = found[0];
  if (!user) {
    const err = new Error('User not found');
    err.status = 404;
    throw err;
  }
  if (user.provider !== 'local') {
    const err = new Error('Only email and password accounts can change their name here.');
    err.status = 403;
    throw err;
  }

  const { rows } = await query(
    `UPDATE users SET name = $1, updated_at = NOW() WHERE id = $2
     RETURNING id, email, name, picture, provider, created_at`,
    [displayName, uid]
  );
  return rows[0];
}

/** Change password for a local account (requires current password). */
export async function changeLocalPassword(userId, { currentPassword, password, confirmPassword }) {
  const uid = Number(userId);
  if (!uid || Number.isNaN(uid)) {
    const err = new Error('Not signed in');
    err.status = 401;
    throw err;
  }
  if (!currentPassword || !password) {
    const err = new Error('Current password and new password are required');
    err.status = 400;
    throw err;
  }
  if (confirmPassword != null && String(password) !== String(confirmPassword)) {
    const err = new Error('Password and confirm password do not match');
    err.status = 400;
    throw err;
  }
  if (String(password).length < 8) {
    const err = new Error('Password must be at least 8 characters');
    err.status = 400;
    throw err;
  }
  if (String(currentPassword) === String(password)) {
    const err = new Error('New password must be different from your current password');
    err.status = 400;
    throw err;
  }

  const { rows } = await query(`SELECT * FROM users WHERE id = $1 LIMIT 1`, [uid]);
  const user = rows[0];
  if (!user) {
    const err = new Error('User not found');
    err.status = 404;
    throw err;
  }
  if (user.provider !== 'local') {
    const err = new Error('Only email and password accounts can change their password here.');
    err.status = 403;
    throw err;
  }

  const ok = await verifyPassword(currentPassword, user.password_hash);
  if (!ok) {
    const err = new Error('Current password is incorrect');
    err.status = 401;
    throw err;
  }

  const password_hash = await hashPassword(password);
  await query(`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`, [
    password_hash,
    uid,
  ]);
  return { message: 'Password updated' };
}

/**
 * Signup email probe: whether this email is already registered (non-guest)
 * and how (local password vs Google, etc.).
 */
export async function lookupEmailForSignup(email) {
  const emailNorm = String(email || '')
    .trim()
    .toLowerCase();
  if (!emailNorm) {
    const err = new Error('Email is required');
    err.status = 400;
    throw err;
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
    const err = new Error('Enter a valid email address');
    err.status = 400;
    throw err;
  }

  const { rows } = await query(
    `SELECT provider FROM users
     WHERE LOWER(email) = $1 AND provider <> 'guest'
     ORDER BY CASE provider
       WHEN 'local' THEN 0
       WHEN 'google' THEN 1
       WHEN 'microsoft' THEN 2
       WHEN 'facebook' THEN 3
       ELSE 9
     END
     LIMIT 1`,
    [emailNorm]
  );

  if (!rows[0]) {
    return { exists: false, email: emailNorm, provider: null };
  }

  return {
    exists: true,
    email: emailNorm,
    provider: rows[0].provider || 'local',
  };
}

/** Create local email/password user (provider = local) */
export async function createLocalUser({ name, email, password }) {
  const emailNorm = String(email || '')
    .trim()
    .toLowerCase();
  const displayName = String(name || '').trim() || emailNorm.split('@')[0] || 'User';
  if (!emailNorm || !password) {
    const err = new Error('Email and password are required');
    err.status = 400;
    throw err;
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
    const err = new Error('Enter a valid email address');
    err.status = 400;
    throw err;
  }
  if (String(password).length < 8) {
    const err = new Error('Password must be at least 8 characters');
    err.status = 400;
    throw err;
  }

  const { rows: taken } = await query(
    `SELECT id, provider FROM users WHERE provider = 'local' AND LOWER(email) = $1 LIMIT 1`,
    [emailNorm]
  );
  if (taken[0]) {
    const err = new Error('An account with this email already exists. Please log in.');
    err.status = 409;
    throw err;
  }

  // Same email already used with Google / other OAuth — do not create a password account
  await assertEmailExclusiveToProvider(emailNorm, 'local');

  const password_hash = await hashPassword(password);
  const { rows } = await query(
    `INSERT INTO users (email, name, picture, provider, provider_id, password_hash)
     VALUES ($1, $2, NULL, 'local', $3, $4) RETURNING id, email, name, picture, provider, created_at`,
    [emailNorm, displayName, emailNorm, password_hash]
  );
  return rows[0];
}

/** Authenticate local user by email + password */
export async function authenticateLocalUser(email, password) {
  const emailNorm = String(email || '')
    .trim()
    .toLowerCase();
  if (!emailNorm || !password) {
    const err = new Error('Email and password are required');
    err.status = 400;
    throw err;
  }

  const { rows } = await query(
    `SELECT * FROM users WHERE provider = 'local' AND LOWER(email) = $1 LIMIT 1`,
    [emailNorm]
  );
  const user = rows[0];
  if (!user) {
    // If they only have Google, give a clearer error
    const { rows: google } = await query(
      `SELECT id FROM users WHERE LOWER(email) = $1 AND provider = 'google' LIMIT 1`,
      [emailNorm]
    );
    if (google[0]) {
      const err = new Error('This email uses Google sign-in. Please continue with Google.');
      err.status = 401;
      throw err;
    }
    const err = new Error('Invalid email or password');
    err.status = 401;
    throw err;
  }

  const ok = await verifyPassword(password, user.password_hash);
  if (!ok) {
    const err = new Error('Invalid email or password');
    err.status = 401;
    throw err;
  }

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    picture: user.picture,
    provider: user.provider,
    created_at: user.created_at,
  };
}

/**
 * Guest login: shared demo account with seeded sample data (not events).
 * Session changes are reset on logout; baseline seed is restored.
 */
export async function createGuestUser() {
  return ensureGuestDemoReady();
}

/**
 * Guest logout cleanup:
 * - Keep the shared demo guest account
 * - Delete guest-added rows and any events
 * - Restore baseline seed (undo edits to demo rows)
 * - Revoke refresh tokens for this user
 */
export async function deleteGuestUserCompletely(userId) {
  const user = await getUserById(userId);
  if (!user || user.provider !== 'guest') {
    return { deleted: false, reason: 'not_guest' };
  }
  await query(`DELETE FROM refresh_tokens WHERE user_id = $1`, [userId]);

  // Shared demo guest: reset data in place (seed stays / is restored).
  if (user.provider_id === SHARED_GUEST_PROVIDER_ID) {
    await resetGuestDemoData(userId);
    return { deleted: false, reset: true, reason: 'demo_reset' };
  }

  // Legacy one-off guest accounts: remove entirely.
  await query(`DELETE FROM users WHERE id = $1 AND provider = 'guest'`, [userId]);
  return { deleted: true };
}
