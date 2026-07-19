# Deploy Sanchiva to GitHub + the internet

**Sanchiva** needs three things online:

1. **Code** → GitHub  
2. **API + UI** → Render (recommended single service)  
3. **Database** → Render Postgres (or Neon)

GitHub alone stores code. GitHub Pages cannot run Express/PostgreSQL.

---

## A. Push code to GitHub

### 1. Create empty repo
1. Open https://github.com/new  
2. Repository name: `sanchiva-web` (or any name)  
3. Public or Private  
4. **Do not** add README / gitignore  
5. Create repository  

### 2. From your PC (PowerShell)

```powershell
cd C:\Users\ujjwa\expense-tracker

git init
git add .
git status
# Confirm server/.env is NOT listed

git commit -m "Sanchiva web app — ready for deploy"
git branch -M main

# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/sanchiva-web.git
git push -u origin main
```

Login when prompted (GitHub username + Personal Access Token as password if asked).

---

## B. Live app on Render (easiest full stack)

### Option 1 — Blueprint (`render.yaml`)

1. Go to https://dashboard.render.com  
2. **New → Blueprint**  
3. Connect the GitHub repo `sanchiva-web`  
4. Apply the blueprint (creates web service + free Postgres)  
5. Wait for first deploy  

App URL will look like: `https://sanchiva.onrender.com`

Free tier may **sleep** after idle; first load can take ~30–60s.

### Option 2 — Manual

1. **New → PostgreSQL** (free) → copy **Internal Database URL**  
2. **New → Web Service** → connect GitHub repo  
3. Settings:

| Setting | Value |
|--------|--------|
| Root Directory | *(leave empty)* |
| Build Command | `npm install --prefix server && npm install --prefix client && npm run build --prefix client` |
| Start Command | `npm run db:init --prefix server && npm start --prefix server` |

4. Environment variables:

| Key | Value |
|-----|--------|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | *(paste Postgres URL)* |
| `CLIENT_ORIGIN` | `*` |
| `PORT` | `10000` (Render sets this automatically often) |

5. Deploy  

The server serves the built React app from `client/dist` on the same URL.

---

## C. Split hosting (optional)

- **Frontend:** Vercel/Netlify → root `client`, build `npm run build`, output `dist`  
- **Env:** `VITE_API_URL=https://your-api.onrender.com`  
- **Backend:** Render web service for `server` only  
- **CORS:** set `CLIENT_ORIGIN=https://your-app.vercel.app`

---

## D. After first deploy

1. Open `https://YOUR-APP.onrender.com/api/health`  
   - Expect `{ "ok": true, "db": true }`  
2. Open the site root and add a daily expense  
3. If DB fails, check `DATABASE_URL` and redeploy  

---

## Local secrets (never on GitHub)

- `server/.env` — local only  
- `keystore` / mobile secrets — not in this repo  

---

## Developed by

**Ujjwal Gupta** · Sanchiva  
© Sanchiva. All rights reserved.
