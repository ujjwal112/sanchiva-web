# HTTPS for Sanchiva on Oracle VM (DuckDNS + Caddy + Let's Encrypt)

Your hostname: **`sanchivaorg.duckdns.org`** → public IP of the VM.

This gives free trusted HTTPS for both UI and API:

- `https://sanchivaorg.duckdns.org/`
- `https://sanchivaorg.duckdns.org/api/...`

---

## Prerequisites

1. DuckDNS points to the **current** Oracle public IP  
2. App already works on **HTTP**: `http://sanchivaorg.duckdns.org/api/health`  
3. Oracle **Security List** ingress:

| Source | Protocol | Port |
|--------|----------|------|
| `0.0.0.0/0` | TCP | **22** |
| `0.0.0.0/0` | TCP | **80** (needed for Let's Encrypt + redirect) |
| `0.0.0.0/0` | TCP | **443** (HTTPS) |

4. On VM, `ufw` if enabled:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

---

## Step 1 — Point app only at localhost:5000 (Caddy will own 80/443)

Edit compose so the app is **not** published on host port 80:

```bash
cd ~/sanchiva-web
nano docker-compose.oracle.yml
```

Under `app` → `ports:`, change:

```yaml
    ports:
      - "5000:5000"
```

(was `"80:5000"`)

Update `.env` for HTTPS:

```bash
nano .env
```

```env
APP_URL=https://sanchivaorg.duckdns.org
API_URL=https://sanchivaorg.duckdns.org
CLIENT_ORIGIN=https://sanchivaorg.duckdns.org
```

Recreate app:

```bash
docker compose -f docker-compose.oracle.yml up -d --force-recreate app
```

Check locally on the VM:

```bash
curl -s http://127.0.0.1:5000/api/health
```

---

## Step 2 — Install Caddy on the VM

```bash
sudo apt-get update
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
caddy version
```

---

## Step 3 — Install Caddyfile

```bash
cd ~/sanchiva-web
sudo cp Caddyfile.oracle /etc/caddy/Caddyfile
# or if file not in repo yet:
sudo tee /etc/caddy/Caddyfile > /dev/null << 'EOF'
sanchivaorg.duckdns.org {
	encode gzip
	reverse_proxy 127.0.0.1:5000

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options nosniff
		X-Frame-Options SAMEORIGIN
		Referrer-Policy strict-origin-when-cross-origin
		-Server
	}
}
EOF
```

Start Caddy:

```bash
sudo systemctl enable caddy
sudo systemctl restart caddy
sudo systemctl status caddy
```

Caddy will:

1. Get a **free Let's Encrypt** certificate for `sanchivaorg.duckdns.org`  
2. Serve **HTTPS on 443**  
3. Redirect HTTP → HTTPS automatically  

Logs if something fails:

```bash
sudo journalctl -u caddy -f
```

---

## Step 4 — Test

| URL | Expect |
|-----|--------|
| https://sanchivaorg.duckdns.org/api/health | `{"ok":true,"db":true,...}` |
| https://sanchivaorg.duckdns.org/ | Sanchiva UI (padlock in browser) |
| https://sanchivaorg.duckdns.org/api/docs | Swagger |

---

## Step 5 — Google OAuth (update)

In [Google Cloud Console](https://console.cloud.google.com/) → OAuth client:

**JavaScript origins**

```text
https://sanchivaorg.duckdns.org
```

**Redirect URI**

```text
https://sanchivaorg.duckdns.org/api/auth/google/callback
```

(You can keep the old `http://...` entries temporarily, then remove them.)

VM `.env` already uses `https://` after Step 1.

---

## If certificate fails

| Error | Fix |
|--------|-----|
| DNS not pointing to VM | DuckDNS IP = current public IP |
| Port 80 blocked | Security list + ufw allow 80 |
| Port 443 blocked | Security list + ufw allow 443 |
| App not on 5000 | `curl http://127.0.0.1:5000/api/health` on VM |
| Rate limit Let's Encrypt | Wait / check Caddy logs |

---

## Architecture after HTTPS

```text
Internet
   │
   ├─ :80  → Caddy (redirect to HTTPS / ACME challenge)
   └─ :443 → Caddy (TLS) → 127.0.0.1:5000 (Sanchiva app)
                              └─ Postgres (Docker, private)
```

---

## Optional: keep using IP on HTTP

Not needed once HTTPS works. Prefer always open:

**https://sanchivaorg.duckdns.org**
