import { Router } from 'express';
import passport from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as FacebookStrategy } from 'passport-facebook';
import { Strategy as MicrosoftStrategy } from 'passport-microsoft';
import {
  findOrCreateOAuthUser,
  signAccessToken,
  issueRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
  getUserById,
  createGuestUser,
  deleteGuestUserCompletely,
} from './tokens.js';
import { requireAuth } from './middleware.js';

const router = Router();

function appUrl() {
  return (process.env.APP_URL || process.env.RENDER_EXTERNAL_URL || 'http://localhost:5173').replace(
    /\/$/,
    ''
  );
}

function apiUrl() {
  // When UI and API share same host (Render), callbacks hit this server
  return (process.env.API_URL || process.env.APP_URL || process.env.RENDER_EXTERNAL_URL || `http://localhost:${process.env.PORT || 5000}`).replace(
    /\/$/,
    ''
  );
}

function callbackRedirect(res, { accessToken, refreshToken, error }) {
  const front = appUrl();
  if (error) {
    return res.redirect(`${front}/login?error=${encodeURIComponent(error)}`);
  }
  // Hash fragment so tokens are not sent to server logs as easily as query
  const q = new URLSearchParams({
    access_token: accessToken,
    refresh_token: refreshToken,
  });
  return res.redirect(`${front}/auth/callback?${q.toString()}`);
}

async function finishOAuth(profile, provider, done) {
  try {
    const providerId = String(profile.id);
    const email =
      profile.emails?.[0]?.value ||
      profile._json?.email ||
      profile._json?.userPrincipalName ||
      `${providerId}@${provider}.local`;
    const name =
      profile.displayName ||
      [profile.name?.givenName, profile.name?.familyName].filter(Boolean).join(' ') ||
      email.split('@')[0];
    const picture =
      profile.photos?.[0]?.value || profile._json?.picture || profile._json?.avatar_url || null;

    const user = await findOrCreateOAuthUser({
      provider,
      providerId,
      email,
      name,
      picture,
    });
    done(null, user);
  } catch (err) {
    done(err);
  }
}

export function configurePassport() {
  const googleId = process.env.GOOGLE_CLIENT_ID;
  const googleSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (googleId && googleSecret) {
    passport.use(
      new GoogleStrategy(
        {
          clientID: googleId,
          clientSecret: googleSecret,
          callbackURL: `${apiUrl()}/api/auth/google/callback`,
        },
        async (_accessToken, _refreshToken, profile, done) => {
          finishOAuth(profile, 'google', done);
        }
      )
    );
  }

  const fbId = process.env.FACEBOOK_APP_ID;
  const fbSecret = process.env.FACEBOOK_APP_SECRET;
  if (fbId && fbSecret) {
    passport.use(
      new FacebookStrategy(
        {
          clientID: fbId,
          clientSecret: fbSecret,
          callbackURL: `${apiUrl()}/api/auth/facebook/callback`,
          profileFields: ['id', 'displayName', 'emails', 'photos'],
        },
        async (_accessToken, _refreshToken, profile, done) => {
          finishOAuth(profile, 'facebook', done);
        }
      )
    );
  }

  const msId = process.env.MICROSOFT_CLIENT_ID;
  const msSecret = process.env.MICROSOFT_CLIENT_SECRET;
  if (msId && msSecret) {
    passport.use(
      new MicrosoftStrategy(
        {
          clientID: msId,
          clientSecret: msSecret,
          callbackURL: `${apiUrl()}/api/auth/microsoft/callback`,
          scope: ['user.read'],
          tenant: process.env.MICROSOFT_TENANT || 'common',
        },
        async (_accessToken, _refreshToken, profile, done) => {
          finishOAuth(profile, 'microsoft', done);
        }
      )
    );
  }
}

async function issueTokensAndRedirect(req, res) {
  try {
    const user = req.user;
    if (!user) return callbackRedirect(res, { error: 'Login failed' });
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    return callbackRedirect(res, { accessToken, refreshToken });
  } catch (e) {
    return callbackRedirect(res, { error: e.message || 'Login failed' });
  }
}

function providerEnabled(name) {
  if (name === 'google') return !!(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET);
  if (name === 'facebook') return !!(process.env.FACEBOOK_APP_ID && process.env.FACEBOOK_APP_SECRET);
  if (name === 'microsoft')
    return !!(process.env.MICROSOFT_CLIENT_ID && process.env.MICROSOFT_CLIENT_SECRET);
  return false;
}

router.get('/providers', (_req, res) => {
  res.json({
    google: providerEnabled('google'),
    facebook: providerEnabled('facebook'),
    microsoft: providerEnabled('microsoft'),
    guest: true,
  });
});

/** Guest login — no OAuth; data wiped on logout */
router.post('/guest', async (_req, res) => {
  try {
    const user = await createGuestUser();
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    res.status(201).json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'Bearer',
      expires_in: 900,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        provider: user.provider,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/google', (req, res, next) => {
  if (!providerEnabled('google')) {
    return res.status(503).json({ error: 'Google login is not configured' });
  }
  passport.authenticate('google', { scope: ['profile', 'email'], session: false })(req, res, next);
});

router.get(
  '/google/callback',
  (req, res, next) => {
    passport.authenticate('google', { session: false, failureRedirect: `${appUrl()}/login?error=google` })(
      req,
      res,
      next
    );
  },
  issueTokensAndRedirect
);

router.get('/facebook', (req, res, next) => {
  if (!providerEnabled('facebook')) {
    return res.status(503).json({ error: 'Facebook login is not configured' });
  }
  passport.authenticate('facebook', { scope: ['email', 'public_profile'], session: false })(
    req,
    res,
    next
  );
});

router.get(
  '/facebook/callback',
  (req, res, next) => {
    passport.authenticate('facebook', {
      session: false,
      failureRedirect: `${appUrl()}/login?error=facebook`,
    })(req, res, next);
  },
  issueTokensAndRedirect
);

router.get('/microsoft', (req, res, next) => {
  if (!providerEnabled('microsoft')) {
    return res.status(503).json({ error: 'Microsoft login is not configured' });
  }
  passport.authenticate('microsoft', { session: false })(req, res, next);
});

router.get(
  '/microsoft/callback',
  (req, res, next) => {
    passport.authenticate('microsoft', {
      session: false,
      failureRedirect: `${appUrl()}/login?error=microsoft`,
    })(req, res, next);
  },
  issueTokensAndRedirect
);

router.post('/refresh', async (req, res) => {
  try {
    const { refresh_token: refreshToken } = req.body || {};
    if (!refreshToken) return res.status(400).json({ error: 'refresh_token required' });
    const rotated = await rotateRefreshToken(refreshToken);
    if (!rotated) return res.status(401).json({ error: 'Invalid or expired refresh token' });
    const user = await getUserById(rotated.userId);
    if (!user) return res.status(401).json({ error: 'User not found' });
    const accessToken = signAccessToken(user);
    res.json({
      access_token: accessToken,
      refresh_token: rotated.refreshToken,
      token_type: 'Bearer',
      expires_in: 900,
      user,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/logout', requireAuth, async (req, res) => {
  try {
    const { refresh_token: refreshToken } = req.body || {};
    if (refreshToken) await revokeRefreshToken(refreshToken);

    // Guest sessions: delete all data + guest user for this session
    const full = await getUserById(req.user.id);
    if (full?.provider === 'guest') {
      await deleteGuestUserCompletely(req.user.id);
      return res.json({ success: true, guest_data_deleted: true });
    }

    res.json({ success: true, guest_data_deleted: false });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) return res.status(401).json({ error: 'User not found' });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
