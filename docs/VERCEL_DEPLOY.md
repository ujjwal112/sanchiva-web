# Deploy Sanchiva on Vercel (frontend + API)

Vercel hosts:

1. **Frontend** — Vite React build (`client/dist`)  
2. **Backend** — Express as one serverless function (`/api/*` → `api/index.js`)  
3. **Database** — still **Supabase** (or Neon). Vercel does not host Postgres.

Same origin: leave `VITE_API_URL` **empty** so the browser calls `/api` on your Vercel domain.

---

## 1. Prerequisites

- GitHub repo with latest code  
- Supabase (or Neon) `DATABASE_URL` ready  
- [Vercel account](https://vercel.com) linked to GitHub  

---

## 2. Import project on Vercel

1. [vercel.com/new](https://vercel.com/new) → import `sanchiva-web`  
2. **Root directory:** leave as repo root (where `vercel.json` lives)  
3. Framework preset: **Other** (config comes from `vercel.json`)  
4. Do **not** override install/build if `vercel.json` is present  

---

## 3. Environment variables (Vercel → Project → Settings → Environment Variables)

Set for **Production** (and Preview if you want):

| Key | Example / notes |
|-----|------------------|
| `DATABASE_URL` | Supabase **Session pooler** or **Transaction pooler** URI + `?sslmode=require` |
| `PGSSL` | `true` |
| `NODE_ENV` | `production` |
| `JWT_ACCESS_SECRET` | long random string |
| `JWT_REFRESH_SECRET` | long random string |
| `CLIENT_ORIGIN` | `https://YOUR-APP.vercel.app` or `*` |
| `APP_URL` | `https://YOUR-APP.vercel.app` |
| `API_URL` | `https://YOUR-APP.vercel.app` |
| `GOOGLE_CLIENT_ID` | optional OAuth |
| `GOOGLE_CLIENT_SECRET` | optional OAuth |

**Do not set** `VITE_API_URL` for same-domain deploy (empty = `/api` on Vercel).

### Database tip (serverless)

Express on Vercel opens short-lived functions. Prefer Supabase:

- **Transaction pooler** port `6543`, or  
- **Session pooler** port `5432`  

Copy from Supabase **Connect** UI.

---

## 4. Deploy

1. Click **Deploy**  
2. Wait for build (client) + function (API)  
3. Open: `https://YOUR-APP.vercel.app/api/health`  
   - Expect: `{ "ok": true, "db": true, "platform": "vercel" }`  
4. Open site root and log in  

---

## 5. Init schema (first time)

Vercel does not run `db:init` on every deploy. Run once against Supabase:

```powershell
cd C:\Users\ujjwa\expense-tracker\server
# temporarily set DATABASE_URL in server/.env to Supabase
npm run db:init
```

Or keep using tables you already migrated from Neon.

---

## 6. Google OAuth (if used)

Google Cloud Console → authorized redirect URI:

```text
https://YOUR-APP.vercel.app/api/auth/google/callback
```

Match `APP_URL` / `API_URL` to the Vercel URL.

---

## 7. Local still works

```powershell
cd C:\Users\ujjwa\expense-tracker
npm run dev
```

- UI: http://localhost:5173  
- API: http://localhost:5000  

---

## Limits to know

| Topic | Note |
|-------|------|
| Free function timeout | ~10s (Hobby) — long metals/FX calls should be OK if under limit |
| Cold starts | First `/api` after idle can be slower than Render always-on |
| WebSockets | Not needed for Sanchiva |
| File uploads | Not used |

If free timeouts are tight later, keep **API on Render** and only put the **frontend on Vercel** with `VITE_API_URL=https://your-api.onrender.com`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `/api/health` 404 | Confirm `api/index.js` and rewrites in `vercel.json` |
| `db: false` | Check `DATABASE_URL` + SSL; use Supabase pooler string from dashboard |
| Frontend calls wrong host | Clear `VITE_API_URL` and redeploy |
| Build fails on client | Ensure `installCommand` installs client with devDependencies (Vite) |
| CORS errors | Set `CLIENT_ORIGIN` to your Vercel URL or `*` |

---

## Files added for Vercel

| File | Role |
|------|------|
| `vercel.json` | Install, build, static out, rewrites |
| `api/index.js` | Serverless Express entry |
| `server/src/app.js` | Express app (shared) |
| `server/src/index.js` | Local/Render `listen` only when not on Vercel |
