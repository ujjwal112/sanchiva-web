# Sanchiva OAuth setup (Google / Facebook / Microsoft)

After deploy, set these on **Render → sanchiva → Environment**:

## Required for all providers

| Key | Example |
|-----|---------|
| `APP_URL` | `https://sanchiva.onrender.com` |
| `API_URL` | `https://sanchiva.onrender.com` |
| `JWT_ACCESS_SECRET` | long random string |
| `JWT_REFRESH_SECRET` | another long random string |

## Google

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials  
2. Create **OAuth client ID** → Web application  
3. Authorized redirect URI:
   ```
   https://sanchiva.onrender.com/api/auth/google/callback
   ```
4. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` on Render  

## Facebook

1. [Meta Developers](https://developers.facebook.com/) → My Apps → Create  
2. Add Facebook Login → Valid OAuth Redirect URIs:
   ```
   https://sanchiva.onrender.com/api/auth/facebook/callback
   ```
3. Set `FACEBOOK_APP_ID` and `FACEBOOK_APP_SECRET`  

## Microsoft

1. [Azure Portal](https://portal.azure.com/) → App registrations → New  
2. Redirect URI (Web):
   ```
   https://sanchiva.onrender.com/api/auth/microsoft/callback
   ```
3. Certificates & secrets → new client secret  
4. Set `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT=common`  

## After setting env vars

1. **Manual Deploy** on Render  
2. Open `https://sanchiva.onrender.com/login`  
3. Sign in → you should land on Dashboard with your name top-left  

## How auth works

- **Access token** (JWT, ~15 min) sent as `Authorization: Bearer …`  
- **Refresh token** (30 days, rotated, stored hashed in DB)  
- All data tables scoped by `user_id` — users only see their own data  

## Local dev

Add the same env vars to `server/.env` with:

```
APP_URL=http://localhost:5173
API_URL=http://localhost:5000
```

And redirect URIs for `http://localhost:5000/api/auth/.../callback`.
