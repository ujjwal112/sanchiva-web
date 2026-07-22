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
  createLocalUser,
  authenticateLocalUser,
  publicUser,
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

/** Deep link back into the Android WebView APK after browser OAuth */
const ANDROID_PACKAGE = 'com.sanchiva.app';
const ANDROID_APP_SCHEME = 'sanchiva://auth/callback';

/**
 * Chrome Custom Tabs often ignore bare custom-scheme 302s.
 * Serve a tiny HTML bridge that opens the app via Android Intent + sanchiva://.
 */
function sendAndroidAppReturn(res, { accessToken, refreshToken, error }) {
  const q = error
    ? `error=${encodeURIComponent(error)}`
    : new URLSearchParams({
        access_token: accessToken || '',
        refresh_token: refreshToken || '',
      }).toString();

  const deepLink = `${ANDROID_APP_SCHEME}?${q}`;
  // Intent URL is the most reliable way to return from Custom Tabs → APK
  const intentLink = `intent://auth/callback?${q}#Intent;scheme=sanchiva;package=${ANDROID_PACKAGE};end`;
  const webFallback = `${appUrl()}/auth/callback?${q}`;

  res
    .status(200)
    .set({
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    })
    .send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Opening Sanchiva…</title>
  <style>
    body { font-family: system-ui, sans-serif; background:#0a0a0c; color:#f5f5f7;
      display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; padding:1.5rem; text-align:center; }
    a { color:#8ab4ff; }
    .card { max-width:22rem; }
    .btn { display:inline-block; margin-top:1rem; padding:.75rem 1.25rem; border-radius:999px;
      background:linear-gradient(135deg,#5b8cff,#7c5cff); color:#fff; text-decoration:none; font-weight:600; }
  </style>
  <script>
    (function () {
      var intent = ${JSON.stringify(intentLink)};
      var deep = ${JSON.stringify(deepLink)};
      function go() {
        try { window.location.replace(intent); } catch (e) {}
        setTimeout(function () {
          try { window.location.href = deep; } catch (e2) {}
        }, 350);
      }
      go();
      setTimeout(go, 800);
    })();
  </script>
</head>
<body>
  <div class="card">
    <h1 style="font-size:1.25rem;margin:0 0 .5rem">Returning to Sanchiva…</h1>
    <p style="opacity:.75;margin:0">Google sign-in succeeded. Opening the app.</p>
    <a class="btn" href="${deepLink}">Open Sanchiva app</a>
    <p style="opacity:.55;margin-top:1.25rem;font-size:.85rem">
      If nothing happens, <a href="${webFallback}">continue in browser</a>.
    </p>
  </div>
</body>
</html>`);
}

function callbackRedirect(res, { accessToken, refreshToken, error, client }) {
  const isAndroid = client === 'android';

  if (isAndroid) {
    return sendAndroidAppReturn(res, { accessToken, refreshToken, error });
  }

  const front = appUrl();
  if (error) {
    return res.redirect(`${front}/login?error=${encodeURIComponent(error)}`);
  }
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
    // `state` is echoed by Google OAuth (we set it to "android" for the APK)
    const client = req.query.state === 'android' ? 'android' : 'web';
    const user = req.user;
    if (!user) return callbackRedirect(res, { error: 'Login failed', client });
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    return callbackRedirect(res, { accessToken, refreshToken, client });
  } catch (e) {
    return callbackRedirect(res, {
      error: e.message || 'Login failed',
      client: req.query.state === 'android' ? 'android' : 'web',
    });
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
    local: true,
  });
});

function tokenResponse(user, accessToken, refreshToken) {
  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'Bearer',
    expires_in: 900,
    user: publicUser(user),
  };
}

/** Email/password signup */
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, confirm_password: confirmPassword } = req.body || {};
    if (confirmPassword != null && String(password) !== String(confirmPassword)) {
      return res.status(400).json({ error: 'Password and confirm password do not match' });
    }
    const user = await createLocalUser({ name, email, password });
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    res.status(201).json(tokenResponse(user, accessToken, refreshToken));
  } catch (err) {
    const status = err.status || 500;
    res.status(status).json({ error: err.message || 'Signup failed' });
  }
});

/** Email/password login */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const user = await authenticateLocalUser(email, password);
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    res.json(tokenResponse(user, accessToken, refreshToken));
  } catch (err) {
    const status = err.status || 500;
    res.status(status).json({ error: err.message || 'Login failed' });
  }
});

/**
 * Guest login — shared demo account with sample data in all modules except Events.
 * On logout: guest-added rows are removed and demo rows reset to baseline.
 */
router.post('/guest', async (_req, res) => {
  try {
    const user = await createGuestUser();
    if (!user?.id) {
      return res.status(500).json({ error: 'Failed to create guest user' });
    }
    const accessToken = signAccessToken(user);
    const refreshToken = await issueRefreshToken(user.id);
    res.status(201).json(tokenResponse(user, accessToken, refreshToken));
  } catch (err) {
    const msg = err.message || 'Guest login failed';
    if (/relation .* does not exist/i.test(msg)) {
      return res.status(500).json({
        error: 'Database tables missing. Run: npm run db:init --prefix server',
      });
    }
    res.status(500).json({ error: msg });
  }
});

router.get('/google', (req, res, next) => {
  if (!providerEnabled('google')) {
    return res.status(503).json({ error: 'Google login is not configured' });
  }
  // client=android → deep-link back into the mobile APK after OAuth
  const state = req.query.client === 'android' ? 'android' : 'web';
  passport.authenticate('google', {
    scope: ['profile', 'email'],
    session: false,
    state,
  })(req, res, next);
});

router.get(
  '/google/callback',
  (req, res, next) => {
    passport.authenticate('google', { session: false }, (err, user) => {
      if (err || !user) {
        const client = req.query.state === 'android' ? 'android' : 'web';
        return callbackRedirect(res, { error: 'google', client });
      }
      req.user = user;
      return next();
    })(req, res, next);
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

    // Guest: reset demo seed (remove session adds / undo edits); keep shared guest account
    const full = await getUserById(req.user.id);
    if (full?.provider === 'guest') {
      const result = await deleteGuestUserCompletely(req.user.id);
      return res.json({
        success: true,
        guest_data_deleted: !!result.deleted,
        guest_data_reset: !!result.reset,
      });
    }

    res.json({ success: true, guest_data_deleted: false, guest_data_reset: false });
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
