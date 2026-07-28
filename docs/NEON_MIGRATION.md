# Move Sanchiva database to Neon (free Postgres)

Your app already supports Neon. It only needs `DATABASE_URL` (SSL is auto-enabled for `neon.tech`).

Do this **before 18 Aug 2026** so you can copy data from Render first.

---

## 1. Create Neon project

1. Open [https://console.neon.tech](https://console.neon.tech) and sign up (GitHub is fine).
2. **New project**
   - Name: `sanchiva` (or any name)
   - Region: pick one close to you (or close to Render’s region if you know it)
   - Postgres version: **16** (or latest default)
3. After create, open **Dashboard → Connection details**
4. Copy the connection string:

   - Prefer **Pooled connection** (has `-pooler` in the host) for the Render web service  
   - Example shape:

   ```text
   postgresql://USER:PASSWORD@ep-xxxxx-pooler.region.aws.neon.tech/neondb?sslmode=require
   ```

5. Keep that string private (treat it like a password).

---

## 2. Export data from Render (while DB still works)

### A. Get Render’s **External** Database URL

1. [Render Dashboard](https://dashboard.render.com) → your **PostgreSQL** service  
2. Copy **External Database URL** (not Internal — Internal only works inside Render)

### B. Dump on your PC (Windows)

Install Postgres client tools if needed:  
https://www.postgresql.org/download/windows/  
(or use `choco install postgresql` if you use Chocolatey)

PowerShell:

```powershell
# Set URLs (paste your real values; keep quotes)
$env:RENDER_DB = "postgresql://USER:PASS@HOST/DB"
$env:NEON_DB   = "postgresql://USER:PASS@ep-xxxxx-pooler.region.aws.neon.tech/neondb?sslmode=require"

# Dump everything (custom format)
pg_dump $env:RENDER_DB --no-owner --no-acl -F c -f sanchiva.dump
```

If `pg_dump` is not found, use the full path, e.g.:

```powershell
& "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe" $env:RENDER_DB --no-owner --no-acl -F c -f sanchiva.dump
```

---

## 3. Restore into Neon

```powershell
pg_restore --no-owner --no-acl -d $env:NEON_DB sanchiva.dump
```

Ignore harmless warnings about roles/ownership.

### Empty Neon / no old data?

You can skip dump/restore and only point the app at Neon, then on deploy run:

```text
npm run db:init --prefix server
```

That creates tables. **Users/expenses from Render will not appear** unless you dump/restore.

---

## 4. Point Render web service at Neon

1. Render → your **Web Service** (the Sanchiva app, not the old Postgres)  
2. **Environment**  
3. Set / update:

| Key | Value |
|-----|--------|
| `DATABASE_URL` | Neon **pooled** connection string |
| `NODE_ENV` | `production` |
| `PGSSL` | `true` (optional; Neon is already detected) |

4. **Save** → **Manual Deploy** (or wait for auto redeploy)

Confirm start command still initializes schema if needed, e.g.:

```text
npm run db:init --prefix server && npm start --prefix server
```

(`db:init` is safe: uses `CREATE IF NOT EXISTS` + migrations.)

---

## 5. Verify

1. `https://YOUR-APP.onrender.com/api/health` → expect `"db": true`  
2. Log in and check dashboard / expenses / events  
3. If login fails after migrate, confirm you restored **all** tables (including auth users)

---

## 6. Clean up Render Postgres (after you’re sure)

1. Keep Neon working for a few days  
2. Then **delete** the old Render PostgreSQL instance so it doesn’t confuse you  
3. Do **not** delete the web service

---

## Local dev with Neon (optional)

In `server/.env`:

```env
DATABASE_URL=postgresql://USER:PASS@ep-xxxxx-pooler.region.aws.neon.tech/neondb?sslmode=require
PGSSL=true
```

Or keep local Docker/Postgres for day-to-day work and only use Neon in production.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `SSL required` / connection refused | Use URL with `?sslmode=require`; ensure host is Neon |
| `too many connections` | Use the **pooler** (`-pooler`) URL |
| Empty app after switch | You pointed at empty Neon — run restore or accept fresh schema via `db:init` |
| Health `db: false` | Check `DATABASE_URL` on **web service** env (typo, wrong service) |
| Dump fails SSL | Add `?sslmode=require` to Render external URL |

---

## Summary

1. Create Neon project → copy pooled `DATABASE_URL`  
2. `pg_dump` Render external URL → `pg_restore` into Neon  
3. Set Render web service `DATABASE_URL` to Neon → redeploy  
4. Test health + login  
5. Delete old Render DB after confirmation  

Need help while doing it? Share **non-secret** errors only (never paste full connection strings with passwords).
