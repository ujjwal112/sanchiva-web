# Move Sanchiva database to Supabase (faster than Neon free)

Neon free **scales to zero**, so the first API call after idle can take many seconds while the DB wakes up.  
Supabase free still gives you a normal Postgres instance that stays warm with regular traffic (free projects can pause after ~1 week of *no* activity — open the dashboard or hit the app to wake).

Your Express app only needs `DATABASE_URL`. SSL is already enabled for `supabase.co` / pooler hosts.

---

## 1. Create a Supabase project

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard) → sign in  
2. **New project**
   - Name: `sanchiva` (or any name)
   - Database password: **save it** (you only see it once)
   - Region: same idea as Neon — **Singapore (ap-southeast-1)** if you use Asia, or closest to Render  
3. Wait until the project is **Healthy**

---

## 2. Copy the connection string

1. Project → **Connect** (or **Project Settings → Database**)  
2. Under connection strings, prefer for Render (long-lived Node process):

| Type | When to use |
|------|-------------|
| **Session pooler** (port **5432**, host like `*.pooler.supabase.com`) | **Recommended** for Express on Render |
| **Direct** (`db.xxxxx.supabase.co:5432`) | Also fine if IPv6 works from Render |
| **Transaction pooler** (port **6543**) | Better for serverless; optional |

3. Use the **URI** format, for example:

```text
postgresql://postgres.PROJECTREF:YOUR_PASSWORD@aws-0-REGION.pooler.supabase.com:5432/postgres
```

or direct:

```text
postgresql://postgres:YOUR_PASSWORD@db.PROJECTREF.supabase.co:5432/postgres
```

4. Append SSL if missing:

```text
...?sslmode=require
```

**Never commit this URL or paste the password in chat/GitHub.**

---

## 3. Migrate data from Neon → Supabase

Use **PostgreSQL 18** tools (same as before).

```powershell
cd C:\Users\ujjwa\expense-tracker
$env:Path = "C:\Program Files\PostgreSQL\18\bin;" + $env:Path

# Neon (source) — your current Neon URL
$neon = 'postgresql://USER:PASS@HOST/neondb?sslmode=require'

# Supabase (target) — session pooler or direct URI
$supabase = 'postgresql://postgres....@....pooler.supabase.com:5432/postgres?sslmode=require'

# Dump Neon
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" `
  --no-owner --no-acl -F c `
  -f "C:\Users\ujjwa\expense-tracker\sanchiva-neon.dump" `
  --dbname="$neon"

# Restore into Supabase
& "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" `
  --no-owner --no-acl `
  --dbname="$supabase" `
  "C:\Users\ujjwa\expense-tracker\sanchiva-neon.dump"
```

Ignore minor role/owner warnings. Then check:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" --dbname="$supabase" -c "\dt"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" --dbname="$supabase" -c "SELECT COUNT(*) FROM users;"
```

### Empty Supabase (no dump)?

Deploy with schema only:

- Set `DATABASE_URL` on Render to Supabase  
- Keep start command: `npm run db:init --prefix server && npm start --prefix server`  

Tables are created; **old data is not copied** unless you dump/restore.

---

## 4. Point Render at Supabase

1. [Render Dashboard](https://dashboard.render.com) → **web service** `sanchiva`  
2. **Environment**  
3. Set:

| Key | Value |
|-----|--------|
| `DATABASE_URL` | Supabase URI (`?sslmode=require`) |
| `PGSSL` | `true` (optional) |

4. **Save** → **Manual Deploy**  

Do **not** change this in git. Only on Render.

---

## 5. Verify

1. `https://sanchiva.onrender.com/api/health` → `"db": true`  
2. Log in and confirm expenses / events / users look right  
3. Hit the app a few times after idle — should feel snappier than Neon free  

---

## 6. Cleanup

- Delete `sanchiva-neon.dump` from your PC (contains all data)  
- After a few good days, you can pause/delete the Neon project  
- Keep Supabase password in a password manager  

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| SSL / connection refused | Add `?sslmode=require`; copy URI from dashboard, don’t invent host |
| Tenant / user not found (pooler) | Use exact **Session pooler** string from Connect UI (`postgres.ref` user) |
| Empty app | Restored into wrong DB, or forgot dump — re-run restore or `db:init` |
| Free project paused | Open Supabase dashboard once; free can pause after ~7 days inactivity |
| Slow first request still | Render **web** free also sleeps — cold start can be web + DB; paid always-on web helps |

---

## Summary

1. Create Supabase project → copy **Session pooler** (or Direct) URI  
2. `pg_dump` Neon → `pg_restore` Supabase  
3. Render `DATABASE_URL` = Supabase → redeploy  
4. Check `/api/health` + login  
5. Retire Neon when happy  
