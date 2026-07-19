import { verifyAccessToken, getUserById } from './tokens.js';

export function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const payload = verifyAccessToken(token);
    if (payload.type !== 'access') {
      return res.status(401).json({ error: 'Invalid token type' });
    }
    const id = Number(payload.sub);
    if (!id || Number.isNaN(id)) {
      return res.status(401).json({ error: 'Invalid token subject' });
    }
    req.user = {
      id,
      email: payload.email,
      name: payload.name,
      picture: payload.picture,
      provider: payload.provider,
    };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired access token' });
  }
}

/** Optional: load fresh user from DB */
export async function attachUser(req, res, next) {
  try {
    if (!req.user?.id) return next();
    const user = await getUserById(req.user.id);
    if (!user) return res.status(401).json({ error: 'User not found' });
    req.user = user;
    next();
  } catch (e) {
    next(e);
  }
}

export function userId(req) {
  return req.user.id;
}
