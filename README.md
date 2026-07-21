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
- **Events** — smart wizard, event detail page, todos, ceremony guests, exports  
- **About** — app info, developed by, copyright  

### Events module (detail)

**Create (wizard)**  
- Pick event type (Wedding, Birthday, Anniversary, Housewarming, Corporate, Other)  
- Guided questions with auto-scroll between steps  
- Wedding ceremonies multi-select: **Tilak** (first), Engagement, Haldi, Mehendi, Sangeet, Main Wedding, Reception, Other (+ custom name)  
- After selecting ceremonies, wizard asks for **each ceremony’s date**  
- Builds a smart todo checklist from answers  

**My Events list**  
- Card list with **View** (opens full detail page) and **Delete**  

**Event detail page** (`/events/:eventId`)  
Separate page with section tabs and **← My Events** on the right of the tab row:

| Tab | What you get |
|-----|----------------|
| **Overview** | Budget KPIs + progress; **ceremony cards** (name, date, themed color, quote) |
| **Budget charts** | Category pie + paid vs remaining |
| **Todos** | Form at top (add / full **Edit** including task name); list with Done checkbox, **Delete**; **10 per page** pagination; **Excel & PDF** download of full list |
| **Guests** | Ceremony-wise tabs only (no “General”); add/edit/delete; pagination (10); **Excel & PDF** export |

**Ceremony overview cards**  
Color and quote follow the ceremony type, for example:  
- **Tilak** — saffron / orange  
- **Haldi** — turmeric gold  
- **Mehendi** — green  
- **Sangeet** — purple  
- **Engagement** — rose  
- **Main Wedding** — deep red  
- **Reception** — blue  

### Authentication & sessions
- **Landing page** (`/`) — product info with **Login** and **Sign up**  
- **Sign up** (`/signup`) — Google **or** name + email + password + confirm password  
- **Login** (`/login`) — Google **or** email + password; optional **Guest** try-out  
- First Google use creates the account; later Google logins open the same account  
- **Access token** (JWT, short-lived) + **refresh token** (rotated, stored hashed)  
- Top-right user menu (name → **Logout**)  
- **Per-user data** — each logged-in user only sees their own records  
- Guest logout **deletes all guest data** for that session  

### API documentation (Swagger)
Interactive OpenAPI docs (try endpoints in the browser):

| Environment | Swagger UI | OpenAPI JSON | Health |
|-------------|------------|--------------|--------|
| **Production** | [https://sanchiva.onrender.com/api/docs](https://sanchiva.onrender.com/api/docs) | […/api/openapi.json](https://sanchiva.onrender.com/api/openapi.json) | […/api/health](https://sanchiva.onrender.com/api/health) |
| **Local** | http://localhost:5000/api/docs | http://localhost:5000/api/openapi.json | http://localhost:5000/api/health |

**How to use Swagger (with Bearer auth)**
1. Open `/api/docs`  
2. Run **POST /api/auth/guest** → **Try it out** → **Execute** and copy `access_token` from the response  
   (or copy the access token from the app after Google / guest login)  
3. Click **Authorize** (lock icon, top right)  
4. Paste the **access token only** (Swagger adds `Bearer` automatically) → **Authorize** → **Close**  
5. Call any protected endpoint with **Try it out** → **Execute**  

**Note:** Most business endpoints require a valid access token. Public without auth: `/api/health`, `/api/docs`, `/api/auth/guest`, `/api/auth/refresh`, `/api/auth/providers`.

---

## Project structure

```
sanchiva-web/
  client/                 React (Vite) UI
    src/pages/
      Events.jsx          Create wizard + My Events list
      EventDetail.jsx     Overview / charts / todos / guests
    src/utils/
      ceremonyThemes.js   Ceremony colors + quotes
      export.js           Excel / PDF helpers
  server/                 Express API + PostgreSQL
    src/routes/events.js  Wizard, items, guests, ceremony_details
  render.yaml             Render Blueprint (web + Postgres)
  DEPLOY.md               Deploy walkthrough
  AUTH_SETUP.md           OAuth provider setup (Google / Facebook / Microsoft)
  .env.example            Environment variable template
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
| UI (landing) | http://localhost:5173 |
| Sign up | http://localhost:5173/signup |
| Login | http://localhost:5173/login |
| Dashboard (after login) | http://localhost:5173/dashboard |
| API health | http://localhost:5000/api/health |
| **Swagger** | http://localhost:5000/api/docs |
| Events | http://localhost:5173/events |
| Event detail | http://localhost:5173/events/:id |

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
| Events | https://sanchiva.onrender.com/events |
| **Swagger UI** | https://sanchiva.onrender.com/api/docs |
| OpenAPI JSON | https://sanchiva.onrender.com/api/openapi.json |
| Health check | https://sanchiva.onrender.com/api/health |

Free Render instances may sleep when idle; first load can take 30–60 seconds.

---

## API overview

Base path: `/api`

| Area | Examples |
|------|----------|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/guest`, `GET /auth/google`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me` |
| Dashboard | `GET /dashboard` |
| Expenses | `GET/POST /expenses`, `PUT/DELETE /expenses/:id`, week/month summaries |
| Loans | `GET/POST /loans`, `GET /loans/summary` |
| Credit cards | `/credit-cards/spends`, `/credit-cards/emis` |
| Monetary | `/monetary/income`, `/monetary/assets`, `/monetary/money-given` |
| Events | `GET /events`, `GET /events/:id` (includes `ceremonies`, `ceremony_details`, guests by ceremony), `POST /events/wizard`, items & guests CRUD |
| Wizard meta | `GET /events/meta/wizard-questions/:eventType` |
| Categories | `GET/POST /categories/:section` |

Full interactive list: **Swagger** → `/api/docs`

### Event detail response (highlights)
- `ceremony_details` — `[{ name, date, quote, theme }]` for overview cards  
- `ceremonies` — ordered list of real ceremony names (no “General”)  
- `guestsByCeremony` / `ceremonyCounts` — guest lists and headcounts per ceremony  
- `items` / `guests` / `summary` — todos, guests, budget rollup  

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
