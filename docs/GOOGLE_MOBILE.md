# Google Sign-In (Flutter mobile + Oracle API)

## How it works

1. App opens Google account picker (`google_sign_in`).
2. Google returns an **ID token** (and optionally an access token).
3. App posts to **`POST /api/auth/google/mobile`** on `https://sanchivaorg.duckdns.org`.
4. Server verifies the token with Google, find-or-creates the user, returns Sanchiva JWTs.
5. Profile photo uses Google `picture` URL (user can still change it on device).

## Google Cloud Console setup

### 1) Web client (required — already used by website)

**APIs & Services → Credentials → OAuth 2.0 Client IDs → Web application**

- This client’s **Client ID** is your server `GOOGLE_CLIENT_ID`.
- Use the **same Client ID** as Flutter `GOOGLE_SERVER_CLIENT_ID` (so the ID token audience matches).

Authorized redirect URIs (web, already):

```text
https://sanchivaorg.duckdns.org/api/auth/google/callback
```

### 2) Android client (required for the phone)

**Create OAuth client → Android**

| Field | Value |
|--------|--------|
| Package name | `com.sanchiva.sanchiva_mobile` |
| SHA-1 | Debug keystore SHA-1 (see below) |

Get debug SHA-1 on Windows:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

Copy the **SHA-1** line into the Android OAuth client.

For release builds, add the **release keystore** SHA-1 as another fingerprint (or a second Android client).

### 3) iOS client (only if you ship iOS later)

Create an **iOS** OAuth client with your bundle id; optional `GOOGLE_IOS_CLIENT_ID` on the server.

## Server environment (Oracle VM `.env`)

Already needed for web:

```env
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=yyyyy
APP_URL=https://sanchivaorg.duckdns.org
API_URL=https://sanchivaorg.duckdns.org
```

Optional extra audiences for mobile ID tokens:

```env
# Usually not required if Android uses Web client as serverClientId
GOOGLE_ANDROID_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

After changing `.env`, recreate the app container:

```bash
cd ~/sanchiva-web
sudo docker compose -f docker-compose.oracle.yml up -d --force-recreate app
```

Deploy the new code with **`POST /api/auth/google/mobile`** (this repo’s `server/src/auth/oauth.js` + `google-auth-library`).

## Flutter run

```powershell
cd C:\Users\ujjwa\expense-tracker\sanchiva_mobile

flutter run -d f2adbd99 `
  --dart-define=API_BASE=https://sanchivaorg.duckdns.org `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Replace `YOUR_WEB_CLIENT_ID` with the **Web** OAuth client ID (not the Android client secret).

## Test API without the app

```bash
curl -sS -X POST https://sanchivaorg.duckdns.org/api/auth/google/mobile \
  -H "Content-Type: application/json" \
  -d '{"id_token":"PASTE_TOKEN_FROM_DEVICE_LOGS"}'
```

Expect JSON with `access_token`, `refresh_token`, and `user`.

## Common errors

| Error | Fix |
|--------|-----|
| Google Sign-In not configured | Pass `GOOGLE_SERVER_CLIENT_ID` |
| Api 10 / DEVELOPER_ERROR | Wrong package name or SHA-1 on Android OAuth client |
| Invalid Google ID token | `serverClientId` must be Web client ID matching server `GOOGLE_CLIENT_ID` |
| Google login is not configured | Set `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET` on VM |
| Network / SSL | App uses `https://sanchivaorg.duckdns.org` |

## OAuth consent screen

App must be in **Testing** with your Gmail as a test user, or **Published**, or sign-in will fail for other accounts.
