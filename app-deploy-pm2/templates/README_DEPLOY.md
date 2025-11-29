# PM2 Application Deployment System
### Deploy Any Next.js / NestJS Application on Any VPS  
### Auto Folders, Deploy Script, Rollback Script, ENV Setup, PM2 Install & GitHub SSH Setup

This system automates deployment of any number of applications (Next.js frontend or NestJS backend) using **PM2**, with automatic environment folders, build flow, rollback and GitHub SSH integration.

It supports deployments across:

```
/var/www/apps/dev/
/var/www/apps/staging/
/var/www/apps/prod/
```

Each app gets **its own PM2 process**, own port, own folder and automated deployment.

---

# 🔐 1. SSH Setup (Required for GitHub Private Repo Access)

### **1️⃣ Create SSH Key**
```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "app-deploy" -f ~/.ssh/app-deploy
cat ~/.ssh/app-deploy.pub
```

Add the **public key** to:

✔ GitHub → SSH Keys → Deploy Keys → Allow Read Access

---

### **2️⃣ SSH Config**
Create:

```bash
nano ~/.ssh/config
```

Add:

```
# Repo: SAARTHI-PORTAL (Air/Bus/Wallet/Rail)
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

---

### **3️⃣ Test SSH Access**
```bash
ssh -T git@saarthi-portal
ssh -T git@infra-stacks
```

---

# 🔧 2. Auto PM2 Install (Handled By deploy.sh)

Your auto-generated `deploy.sh` **automatically installs PM2** if missing:

```bash
if ! command -v pm2 >/dev/null 2>&1; then
    echo "PM2 not found. Installing..."
    sudo npm install -g pm2
fi
```

No manual PM2 installation needed.

---

# 🛠 3. Setup Script

Run:

```bash
cd app-deploy-pm2/scripts
./setup-app.sh
```

You will be asked:

| Question | Example |
|---------|---------|
| App Name | wallet-frontend |
| Environment | dev / staging / prod |
| Domain / PM2 Name | wallet.saarthii.co.in |
| App Type | Next.js / NestJS |
| Port | 6101 |

Generated structure:

```
/var/www/apps/dev/wallet-frontend/
    .env
    deploy.sh
    rollback.sh
```

---

# 📜 4. deploy.sh (Auto Generated)

Includes:

- Git clone / pull  
- Install dependencies  
- Build via Nx  
- Backup old version  
- Deploy new build  
- PM2 restart  
- Nginx reload  
- PM2 auto-install if missing  

---

# 🔁 5. rollback.sh

Rollback instantly:

```bash
cd /var/www/apps/dev/wallet-frontend
./rollback.sh
```

---

# 🔧 6. Environment File

Location:

```
/var/www/apps/dev/<app>/.env
```

Default:

```
NODE_ENV=production
PORT=6101
```

Extend with:

```
API_URL=
MONGO_URI=
REDIS_URI=
```

---

# ⚙️ 7. GitHub Actions Integration

Example workflow:

```yaml
name: Deploy Wallet Frontend (Dev)

on:
  push:
    branches: [ dev ]
    paths: [ "apps/wallet-frontend/**" ]

jobs:
  deploy:
    runs-on: devdbfrontenddevstaging

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: bash /var/www/apps/dev/wallet-frontend/deploy.sh
```

---

# 🧩 When To Use This System

Use PM2 deployment when:

- Many apps run on same VPS  
- You need fast deployments  
- Docker is too heavy  
- You want rollback support  
- You want isolated per-environment folders  

---

# 📌 When To Switch to Docker

Use `app-deploy-docker/` if you want:

- Containers  
- Horizontal scaling  
- Kubernetes later  
- Environment immutability  

---

# 🎉 Final Notes

Your PM2 deployment system is now:

- Fully automated  
- Safe (rollback enabled)  
- Supports all apps  
- Works with GitHub runners  
- Perfect for 20–30 apps  
