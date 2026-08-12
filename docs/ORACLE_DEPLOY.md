# Deploy Sanchiva on Oracle Cloud free VM (UI + API + DB)

One **Always Free** VM runs everything with Docker:

- **Postgres** (always on — no Neon sleep)  
- **Express API** + **React UI** (same origin on port 80)

**Not deployed on Oracle:** the Flutter app under `sanchiva_mobile/`. It is source-only in git. The Docker image only builds `client/` + `server/` (see root `Dockerfile` and `.dockerignore`).

---

## A. Create the free VM (console)

1. Log in: [https://cloud.oracle.com](https://cloud.oracle.com)  
2. Top-left menu → **Compute → Instances → Create instance**  
3. Suggested settings:

| Setting | Suggestion |
|---------|------------|
| Name | `sanchiva-vm` |
| Image | **Canonical Ubuntu 22.04** (or 24.04) |
| Shape | **VM.Standard.A1.Flex** (Ampere ARM) — Always Free if available |
| OCPUs / RAM | e.g. **2 OCPU / 12 GB** (or whatever free quota allows) |
| Networking | Create / use VCN with **public subnet** |
| Public IP | **Assign public IPv4** |
| SSH keys | Generate or upload your public key (save the private key) |

4. **Create** → wait until **Running**.  
5. Copy **Public IP** (example: `130.61.x.x`).

### Open firewall ports (critical)

**1) Oracle Network Security List / NSG**

- VCN → Subnet → Security List → **Ingress**:
  - **TCP 22** (SSH) — source: your IP preferred, or `0.0.0.0/0` carefully  
  - **TCP 80** (HTTP) — `0.0.0.0/0`  
  - (Later) **TCP 443** for HTTPS  

**2) OS firewall** (after SSH) — see section C.

---

## B. SSH into the VM

### From Windows (PowerShell)

```powershell
# Path to the private key you downloaded from Oracle
ssh -i C:\Users\ujjwa\Downloads\ssh-key-xxxx.key ubuntu@YOUR_PUBLIC_IP
```

First connect: type `yes` for host fingerprint.

If key permissions error:

```powershell
icacls C:\Users\ujjwa\Downloads\ssh-key-xxxx.key /inheritance:r
icacls C:\Users\ujjwa\Downloads\ssh-key-xxxx.key /grant:r "$($env:USERNAME):(R)"
```

---

## C. Install Docker on the VM

Run on the **Ubuntu** VM:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker ubuntu
```

Log out and SSH back in so `docker` works without sudo:

```bash
exit
# SSH again
docker --version
docker compose version
```

Optional OS firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw --force enable
```

---

## D. Get the Sanchiva code on the VM

```bash
cd ~
git clone https://github.com/ujjwal112/sanchiva-web.git
cd sanchiva-web
```

(Use your real repo URL if different. For a private repo, use a GitHub personal access token or SSH deploy key.)

---

## E. Configure secrets

```bash
cp .env.oracle.example .env
nano .env
```

Set at least:

```env
POSTGRES_PASSWORD=some_strong_password
JWT_ACCESS_SECRET=long_random_string_1
JWT_REFRESH_SECRET=long_random_string_2
APP_URL=http://YOUR_PUBLIC_IP
API_URL=http://YOUR_PUBLIC_IP
CLIENT_ORIGIN=*
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

---

## F. Build and start (UI + API + DB)

```bash
cd ~/sanchiva-web
docker compose -f docker-compose.oracle.yml up -d --build
```

First build can take **5–15 minutes**. Check:

```bash
docker compose -f docker-compose.oracle.yml ps
docker compose -f docker-compose.oracle.yml logs -f app
```

(`Ctrl+C` stops following logs, containers keep running.)

---

## G. Test

From your browser / phone:

| URL | Expect |
|-----|--------|
| `http://YOUR_PUBLIC_IP/` | Sanchiva UI |
| `http://YOUR_PUBLIC_IP/api/health` | `{"ok":true,"db":true,...}` |
| `http://YOUR_PUBLIC_IP/api/docs` | Swagger UI |

---

## H. Migrate data from Neon/Supabase (optional)

On your **Windows PC** (with `pg_dump` 18):

```powershell
$env:Path = "C:\Program Files\PostgreSQL\18\bin;" + $env:Path
$src = 'postgresql://...neon-or-supabase...?sslmode=require'
pg_dump --no-owner --no-acl -F c -f sanchiva.dump --dbname="$src"
```

Copy dump to VM (from PC):

```powershell
scp -i C:\path\to\key.key sanchiva.dump ubuntu@YOUR_PUBLIC_IP:~/
```

On VM:

```bash
# Install client tools
sudo apt-get install -y postgresql-client

# Restore into Docker Postgres (password from .env)
export PGPASSWORD='your_POSTGRES_PASSWORD'
pg_restore --no-owner --no-acl \
  -h 127.0.0.1 -p 5432 -U sanchiva -d sanchiva \
  ~/sanchiva.dump
```

If port 5432 is not published, use:

```bash
docker compose -f docker-compose.oracle.yml exec -T db \
  pg_restore --no-owner --no-acl -U sanchiva -d sanchiva < ~/sanchiva.dump
```

(Only if the dump is piped correctly; custom format may need `docker cp` into the container.)

Simpler custom-format restore:

```bash
docker cp ~/sanchiva.dump sanchiva-db:/tmp/sanchiva.dump
docker compose -f docker-compose.oracle.yml exec db \
  pg_restore --no-owner --no-acl -U sanchiva -d sanchiva /tmp/sanchiva.dump
```

---

## I. Useful commands

```bash
cd ~/sanchiva-web

# Restart
docker compose -f docker-compose.oracle.yml restart

# Rebuild after git pull
git pull
docker compose -f docker-compose.oracle.yml up -d --build

# Logs
docker compose -f docker-compose.oracle.yml logs -f app
docker compose -f docker-compose.oracle.yml logs -f db

# Stop
docker compose -f docker-compose.oracle.yml down
# Stop + delete DB volume (destructive)
# docker compose -f docker-compose.oracle.yml down -v
```

---

## J. Domain + HTTPS (later, recommended)

1. Point DNS **A record** to your public IP.  
2. Install **Caddy** as reverse proxy on 80/443, or add a `caddy` service.  
3. Set `APP_URL` / `API_URL` to `https://yourdomain.com`.  
4. Google OAuth redirect: `https://yourdomain.com/api/auth/google/callback`.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Can’t SSH | Check key path, security list TCP 22, instance running |
| Site timeout | Open **TCP 80** in VCN security list + `ufw` |
| `db: false` | `docker compose ... logs db` / `app`; check `.env` password |
| Build fails (ARM) | Use Ubuntu ARM image; Node 20 slim supports arm64 |
| Out of memory on build | Use smaller shape temporarily, or build client on PC and copy `dist` |
| Free shape “out of capacity” | Try another region (e.g. Phoenix, Frankfurt) or smaller OCPU/RAM |
| After reboot app down | `restart: unless-stopped` should bring containers back; check `docker ps` |

---

## Architecture

```text
Internet → :80 → sanchiva-app (Express)
                    ├─ /           → React (client/dist)
                    ├─ /api/*      → API
                    └─ DATABASE_URL → sanchiva-db:5432 (Postgres, private)
```

No Neon/Vercel cold starts for this stack: **VM + containers stay running**.

---

## Security checklist

- [ ] Strong `POSTGRES_PASSWORD` and JWT secrets  
- [ ] Do **not** publish Postgres `5432` to the internet  
- [ ] Prefer SSH key only (disable password SSH if possible)  
- [ ] Restrict SSH ingress to your IP when possible  
- [ ] Backup: `docker exec sanchiva-db pg_dump -U sanchiva sanchiva > backup.sql` weekly  
