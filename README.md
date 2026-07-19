# Sanchiva

**Everything that matters — one place.**

Sanchiva is a personal finance web app for tracking daily expenses, loans, credit cards, income, assets, money lent to people, and life events — with secure login and per-user data.

| | |
|--|--|
| **Live app** | [https://sanchiva.onrender.com](https://sanchiva.onrender.com) |
| **Repository** | [github.com/ujjwal112/sanchiva-web](https://github.com/ujjwal112/sanchiva-web) |
| **Stack** | React · Express · PostgreSQL |
| **Developed by** | Ujjwal Gupta |

---

## Features

### App modules
- **Dashboard** — KPIs, charts, month spend, loans, assets overview  
- **Daily Expense** — entry + live list, week/month views, Excel & PDF export  
- **Loans / Credit Cards** — loans, card spends, card EMIs + summaries  
- **Monetary** — salary/income, assets (FD, MF, crypto…), money lent  
- **Events** — create events with checklists, budgets, guest list  
- **About** — app info, developed by, copyright  

### Authentication & sessions
- Login with **Google**, **Facebook**, or **Microsoft** (OAuth)  
- **Guest login** — try the app as **Guest User** without social accounts  
- **Access token** (JWT, short-lived) + **refresh token** (rotated, stored hashed)  
- Top-left user menu (name → **Logout**)  
- **Per-user data** — each logged-in user only sees their own records  
- Guest logout **deletes all guest data** for that session  

### API documentation (Swagger)
Interactive OpenAPI docs (try endpoints in the browser):

| Environment | Swagger UI | OpenAPI JSON | Health |
|-------------|------------|--------------|--------|
| **Production** | [https://sanchiva.onrender.com/api/docs](https://sanchiva.onrender.com/api/docs) | […/api/openapi.json](https://sanchiva.onrender.com/api/openapi.json) | […/api/health](https://sanchiva.onrender.com/api/health) |
| **Local** | http://localhost:5000/api/docs | http://localhost:5000/api/openapi.json | http://localhost:5000/api/health |

**How to use Swagger**
1. Open `/api/docs`  
2. Choose an endpoint (e.g. `GET /api/health`)  
3. Click **Try it out** → **Execute**  
4. For protected routes, click **Authorize** and paste:  
   `Bearer <your_access_token>`  
   (get a token via login / guest login, or from the browser after signing in)

**Note:** Most business endpoints require a valid access token. Public without auth: `/api/health`, `/api/docs`, `/api/auth/*` login routes.

---

## Project structure

```
sanchiva-web/
  client/          React (Vite) UI
  server/          Express API + PostgreSQL
  render.yaml      Render Blueprint (web + Postgres)
  DEPLOY.md        Deploy walkthrough
  AUTH_SETUP.md    OAuth provider setup (Google / Facebook / Microsoft)
  .env.example     Environment variable template
```

---

## Local development

### Requirements
- Node.js **20.x** (recommended)  
- PostgreSQL (local or Docker)

### Setup

```bash
# Install dependencies
npm install
npm run install:all

# Configure environment
# Copy .env.example → server/.env and set DATABASE_URL / JWT secrets / OAuth keys

# Create tables + migrations
npm run db:init

# Run API + UI
npm run dev
```

| Service | URL |
|---------|-----|
| UI | http://localhost:5173 |
| API health | http://localhost:5000/api/health |
| **Swagger** | http://localhost:5000/api/docs |
| Login | http://localhost:5173/login |

Guest login works locally without OAuth. Social logins need client IDs (see **AUTH_SETUP.md**).

### Docker Postgres (optional)

```bash
docker compose up -d
npm run db:init
```

---

## Production deploy (Render)

Full steps: **[DEPLOY.md](./DEPLOY.md)**

**Short version:**
1. Code is on GitHub: `ujjwal112/sanchiva-web`  
2. Deploy with [Render](https://render.com) using `render.yaml` (API + UI + Postgres)  
3. Set environment variables (JWT secrets, `APP_URL`, `API_URL`, optional OAuth keys)  
4. Open https://sanchiva.onrender.com  

OAuth keys: **[AUTH_SETUP.md](./AUTH_SETUP.md)**

### Useful production URLs

| Page | URL |
|------|-----|
| App / login | https://sanchiva.onrender.com/login |
| Dashboard (after login) | https://sanchiva.onrender.com/ |
| **Swagger UI** | https://sanchiva.onrender.com/api/docs |
| OpenAPI JSON | https://sanchiva.onrender.com/api/openapi.json |
| Health check | https://sanchiva.onrender.com/api/health |

Free Render instances may sleep when idle; first load can take 30–60 seconds.

---

## API overview

Base path: `/api`

| Area | Examples |
|------|----------|
| Auth | `POST /auth/guest`, `GET /auth/google`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me` |
| Dashboard | `GET /dashboard` |
| Expenses | `GET/POST /expenses`, `PUT/DELETE /expenses/:id`, week/month summaries |
| Loans | `GET/POST /loans`, `GET /loans/summary` |
| Credit cards | `/credit-cards/spends`, `/credit-cards/emis` |
| Monetary | `/monetary/income`, `/monetary/assets`, `/monetary/money-given` |
| Events | `/events`, `/events/wizard`, items & guests |
| Categories | `GET/POST /categories/:section` |

Full interactive list: **Swagger** → `/api/docs`

---

## Environment variables (summary)

See **`.env.example`** for the full list.

| Key | Purpose |
|-----|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Token signing |
| `APP_URL` / `API_URL` | OAuth redirects (e.g. `https://sanchiva.onrender.com`) |
| `GOOGLE_*` / `FACEBOOK_*` / `MICROSOFT_*` | Social login (optional) |
| `CLIENT_ORIGIN` | CORS (use `*` on single-host Render deploy) |

Never commit `server/.env` or real secrets.

---

## License / copyright

© Sanchiva. All rights reserved.  
**Developed by Ujjwal Gupta.**
