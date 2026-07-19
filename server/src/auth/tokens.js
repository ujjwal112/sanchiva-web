import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';

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
      sub: user.id,
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
  const { rows } = await query(`SELECT id, email, name, picture, provider, created_at FROM users WHERE id = $1`, [
    id,
  ]);
  return rows[0] || null;
}
