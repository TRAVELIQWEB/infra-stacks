---

# ✅ **UPDATED README (Copy–Paste Friendly)**

---

# PM2 Application Deployment System

### Deploy Any Next.js / NestJS Application on Any VPS

### Safe Folder Structure • Auto PM2 Setup • Build/Deploy • Rollback • GitHub CI/CD

This system deploys any number of applications (Next.js frontend or NestJS backend) using **PM2**, with:

* Automatic safe folder structure
* Deploy + rollback scripts
* Environment file isolation
* GitHub SSH setup
* GitHub Actions deployment
* No Docker required

It supports these runtime locations:

```
/var/www/apps/dev/
/var/www/apps/staging/
/var/www/apps/prod/
```

Each app gets **its own PM2 process**, isolated build folders, and safe rollback support.

---

# 🔐 1. SSH Setup (Required for GitHub Private Repo Access)

### **1️⃣ Create SSH Key**

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "app-deploy" -f ~/.ssh/app-deploy
cat ~/.ssh/app-deploy.pub
```

Add the public key to:

✔ GitHub → Deploy Keys → Allow Read Access

---

### **2️⃣ SSH Config**

```
nano ~/.ssh/config
```

Paste:

```
# Repo: SAARTHI-PORTAL
Host saarthi-portal
    HostName github.com
    User git
    IdentityFile ~/.ssh/app-deploy
    IdentitiesOnly yes
    StrictHostKeyChecking no

# Repo: infra-stacks
Host infra-stacks
    HostName github.com
    User git
    IdentityFile ~/.ssh/infra-stacks
    IdentitiesOnly yes
    StrictHostKeyChecking no

# Default fallback
Host github.com
    HostName ssh.github.com
    User git
    Port 443
    IdentityFile ~/.ssh/app-deploy
    IdentitiesOnly yes
    StrictHostKeyChecking no
```

Apply permissions:

```bash
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/app-deploy
```

Test access:

```bash
ssh -T git@saarthi-portal
ssh -T git@infra-stacks
```

---

# 🔧 2. PM2 Auto Install

Your generated deploy scripts already include:

```bash
if ! command -v pm2 >/dev/null 2>&1; then
    sudo npm install -g pm2
fi
```

You do **not** need to install PM2 manually.

---

# 🛠 3. Setup Script

Run:

```bash
cd app-deploy-pm2/scripts
./setup-app.sh
```

It asks:

| Question          | Example               |
| ----------------- | --------------------- |
| App Name          | wallet-frontend       |
| Environment       | dev / staging / prod  |
| Domain / PM2 Name | wallet.saarthii.co.in |
| App Type          | Next.js / NestJS      |
| Port              | 6101                  |

---

# 📁 **Generated Folder Structure (Updated & Safe)**

This system now creates a **safe structure**:

```
/var/www/apps/dev/wallet-frontend/
    scripts/
        deploy.sh
        rollback.sh
    env/
        .env
    current/     <-- current active build
    backup/      <-- last build (rollback)
```

### 🔥 Why this structure?

* Scripts are NEVER removed
* Env file is safe
* Only build folders change
* Rollback is instant & safe

---

# 📜 4. deploy.sh (Updated Safe Version)

Auto-generated deploy script does:

* Clone → Install → Build
* Moves build into `/current/`
* Moves old build to `/backup/`
* Restarts PM2
* Never touches scripts or env folder

Works for both **Next.js** and **NestJS**.

---

# 🔁 5. rollback.sh (Updated Safe Version)

Rollback is now safe:

```bash
rm -rf current/
mv backup/ current/
pm2 restart all
```

Rollback no longer deletes any important folders.

---

# 🔧 6. Environment File

Location is now:

```
/var/www/apps/<env>/<app>/env/.env
```

Example:

```
NODE_ENV=production
PORT=6101
API_URL=
MONGO_URI=
REDIS_URI=
```

---

# ⚙️ 7. GitHub Actions Integration (Updated to New Path)

Use this workflow:

```yaml
name: Deploy Wallet Frontend (Dev)

on:
  push:
    branches: [ dev ]
    paths: [ "apps/wallet-frontend/**" ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: devdbfrontenddevstaging

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: 🚀 Run Deployment
        run: bash /var/www/apps/dev/wallet-frontend/scripts/deploy.sh
```

### 🔥 Important:

Deployment must call:

```
scripts/deploy.sh
```

NOT:

```
deploy.sh
```

---

# 🧩 When To Use This System

Use this PM2 setup when:

* Many apps run on a single VPS
* You want fast deployments
* You need rollback support
* Docker is too heavy
* You want simple file-based deployment

---

# 📌 When To Switch to Docker

Choose `app-deploy-docker/` for:

* Microservices
* Horizontal scaling
* Kubernetes
* Immutable builds

---

# 🎉 Final Notes

Your deployment system is now:

* **Safe** (scripts/env folders never deleted)
* **Modular** (supports many apps easily)
* **Fast** (PM2 is lightweight)
* **Rollback-ready**
* **CI/CD compatible**
* **Ready for production**

---
