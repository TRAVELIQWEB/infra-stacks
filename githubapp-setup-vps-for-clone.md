# 🔐 Secure GitHub Cloning Using GitHub App (For VPS Deployments)

This guide explains **how to clone private GitHub repositories securely on any VPS** using a **GitHub App**, with:

✔ No SSH keys  
✔ No deploy keys  
✔ No Personal Access Tokens  
✔ Repo-scoped, revokable, 1-hour access tokens  

Ideal for **large deployment systems**, multiple VPS, CI/CD, and PM2-based apps.

---

# 🚀 WHY USE A GITHUB APP?

| Method | Safe? | Repo Scoped? | Revokable? | Good for many VPS? |
|--------|-------|--------------|-------------|---------------------|
| SSH Deploy Key | ❌ | ❌ No | ❌ No | ❌ No |
| Personal Access Token | ❌ | ❌ No | ❌ No | ❌ No |
| GitHub App | ✔ | ✔ Yes | ✔ Yes | ✔ Perfect |

GitHub App tokens last **1 hour** and are automatically rotated.

---

# ✅ 1. Create a GitHub App

Go to:

```
GitHub → Settings → Developer settings → GitHub Apps → New GitHub App
```

Fill values:

| Field | Value |
|------|--------|
| **GitHub App name** | fwms-saarthii *(or any name)* |
| **Homepage URL** | https://traveliqweb.co.in |
| **Callback URL** | (leave empty) |
| **Webhook** | Disable or leave empty |
| **Permissions** | Repository → Contents → **Read-only** |
| **Repository access** | Only selected repositories (recommended) |
| **Where can this GitHub App be installed?** | Only this account |

Click **Create GitHub App**.

---

# ✅ 2. Generate Private Key

Download the `.pem` and rename:

```
fwms.pem
```

Move to VPS:

```bash
sudo mkdir -p /opt/github-app
sudo mv fwms.pem /opt/github-app/fwms.pem
sudo chmod 600 /opt/github-app/fwms.pem
```

---

# ✅ 3. Install GitHub App on Repositories

Select only the repos needed:

- wallet-auth  
- wallet-api  
- fwms-api  
- rail-api  
- bus-api  

Record:

- **APP_ID**
- **INSTALLATION_ID**

---

# ✅ 4. Install Dependencies

```bash
sudo apt install jq openssl -y
```

---

# ✅ 5. Create `gh-clone.sh` (FINAL VERSION)

```
#!/bin/bash
set -e

APP_ID=2402629
INSTALLATION_ID=97780972
PRIVATE_KEY="/opt/github-app/fwms.pem"

REPO="$1"
DEST="$2"
BRANCH="$3"

if [[ -z "$REPO" || -z "$DEST" || -z "$BRANCH" ]]; then
  echo "Usage: gh-clone.sh <org/repo> <destination> <branch>"
  exit 1
fi

generate_jwt() {
  local header payload now exp signature

  header=$(printf '{"alg":"RS256","typ":"JWT"}'            | openssl base64 -A | tr '+/' '-_' | tr -d '=')

  now=$(date +%s)
  exp=$((now + 540))

  payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$now" "$exp" "$APP_ID"            | openssl base64 -A | tr '+/' '-_' | tr -d '=')

  signature=$(printf '%s' "$header.$payload"               | openssl dgst -sha256 -sign "$PRIVATE_KEY"               | openssl base64 -A | tr '+/' '-_' | tr -d '=')

  echo "$header.$payload.$signature"
}

echo "🔐 Generating JWT..."
JWT=$(generate_jwt)

echo "🔑 Requesting installation token..."
TOKEN=$(curl -s -X POST   -H "Authorization: Bearer $JWT"   -H "Accept: application/vnd.github+json"   https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens   | jq -r .token)

if [[ "$TOKEN" == "null" ]]; then
  echo "❌ Failed to get installation token"
  exit 1
fi

echo "🧹 Cleaning destination..."
rm -rf "$DEST"

echo "🔽 Cloning $REPO (branch: $BRANCH)..."
git clone --branch "$BRANCH" --depth=1   https://x-access-token:$TOKEN@github.com/$REPO.git "$DEST"

echo "✅ Clone completed!"
```

Make executable:

```bash
sudo chmod +x /opt/github-app/gh-clone.sh
```

---

# ✅ 6. Use in deploy.sh

Replace:

```
git clone --branch "$ENV" git@app-deploy:ORG/REPO.git
```

With:

```
/opt/github-app/gh-clone.sh "ORG/REPO" "$TEMP" "$ENV"
```

---

# 🔒 SECURITY BENEFITS

✔ Tokens expire in 1 hour  
✔ Repo-scoped  
✔ Instantly revokable  
✔ No long-term credentials  
✔ Safe for 50+ VPS  

---
