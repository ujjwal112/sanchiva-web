# Sanchiva (Web)

**Everything that matters — one place.**

Personal finance suite — daily expenses, loans, credit cards, income, assets, money lent, and events.

**Stack:** React · Express · PostgreSQL  
**Developed by Ujjwal Gupta**

---

## Features

- Dashboard with KPIs and charts  
- Daily expense entry + week/month views + Excel/PDF export  
- Loans & credit cards  
- Monetary (income, assets, money lent)  
- Events planner  
- About + copyright  

---

## Local development

### Requirements
- Node.js 18+  
- PostgreSQL (or `docker compose up -d`)

### Setup

```bash
cd expense-tracker
npm install
npm run install:all

# Configure server/.env (see .env.example)
npm run db:init
npm run dev
```

- UI: http://localhost:5173  
- API: http://localhost:5000/api/health  

---

## Deploy to GitHub + live hosting

See **[DEPLOY.md](./DEPLOY.md)** for full steps.

**Short version:**
1. Push this folder to a GitHub repo  
2. Deploy on [Render](https://render.com) with the included `render.yaml` (API + UI + Postgres)  
3. Open the Render URL  

---

## Android app (separate)

Kotlin + local SQLite (no sync with this web app yet):

```
C:\Users\ujjwa\sanchiva-android
```

---

## License / copyright

© Sanchiva. All rights reserved.  
Developed by **Ujjwal Gupta**.
