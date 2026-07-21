import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { query } from '../db.js';

const BCRYPT_ROUNDS = 12;

const ACCESS_TTL = process.env.JWT_ACCESS_TTL || '15m';
const REFRESH_TTL_DAYS = Number(process.env.JWT_REFRESH_DAYS || 30);

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

export async function findOrCreateOAuthUser({ provider, providerId, email, name, picture }) {
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
    [email || `${providerId}@${provider}.oauth`, name || 'User', picture || null, provider, providerId]
  );
  return rows[0];
}

export async function getUserById(id) {
  const uid = Number(id);
  if (!uid || Number.isNaN(uid)) return null;
  const { rows } = await query(
    `SELECT id, email, name, picture, provider, created_at FROM users WHERE id = $1`,
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

  // Soft check: same email via Google — guide them to Google login
  const { rows: oauthHit } = await query(
    `SELECT id, provider FROM users WHERE LOWER(email) = $1 AND provider = 'google' LIMIT 1`,
    [emailNorm]
  );
  if (oauthHit[0]) {
    const err = new Error(
      'This email is already registered with Google. Please use Continue with Google to sign in.'
    );
    err.status = 409;
    throw err;
  }

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

/** Create a one-time guest user for exploring the app */
export async function createGuestUser() {
  const guestId = crypto.randomUUID();
  const { rows } = await query(
    `INSERT INTO users (email, name, picture, provider, provider_id)
     VALUES ($1, $2, NULL, 'guest', $3) RETURNING *`,
    [`guest-${guestId}@sanchiva.local`, 'Guest User', guestId]
  );
  return rows[0];
}

/**
 * Wipe all guest session data and remove the guest account.
 * FK CASCADE on user_id tables handles related rows.
 */
export async function deleteGuestUserCompletely(userId) {
  const user = await getUserById(userId);
  if (!user || user.provider !== 'guest') {
    return { deleted: false, reason: 'not_guest' };
  }
  // Extra cleanup for safety (events cascade via event_id, but explicit is fine)
  await query(`DELETE FROM refresh_tokens WHERE user_id = $1`, [userId]);
  await query(`DELETE FROM users WHERE id = $1 AND provider = 'guest'`, [userId]);
  return { deleted: true };
}
