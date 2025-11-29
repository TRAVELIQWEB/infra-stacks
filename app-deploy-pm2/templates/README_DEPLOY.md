# PM2 Application Deployment System
### Deploy Any Next.js / NestJS Application on Any VPS  
### With Auto-Generated Folders, Deploy Script, Rollback Script & ENV Setup

This module provides a fully-automated deployment system for all your applications using PM2, with support for both Next.js (frontend) and NestJS (backend) projects.

It allows you to deploy any number of apps across:

```
/var/www/apps/dev/
/var/www/apps/staging/
/var/www/apps/prod/
```

Each app gets isolated environments, its own PM2 process name, its own port, and its own rollback system.

---

## 🚀 Features

✔ Supports **Next.js & NestJS** apps  
✔ Auto-generates:  
- deploy.sh  
- rollback.sh  
- .env file  
- folder structure  

✔ PM2 name based on domain  
Example:  
```
air.saarthii.co.in
wallet.saarthii.co.in
```

✔ Automatic Git Clone → Build → Deploy  
✔ Automatic backup + rollback  
✔ Suitable for 20–30 applications  
✔ Easy migration path to Docker later  

---

## 📂 Folder Structure Created

```
/var/www/apps/
    dev/
       wallet-frontend/
           .env
           deploy.sh
           rollback.sh
    prod/
       air-backend/
           .env
           deploy.sh
           rollback.sh
```

---

## 🛠 Setup Script

Run the setup script:

```bash
cd app-deploy-pm2/scripts
./setup-app.sh
```

The script will ask:

| Question | Example |
|---------|---------|
| App Name | wallet-frontend |
| Environment | dev / staging / prod |
| Domain / PM2 Name | wallet.saarthii.co.in |
| App Type | Next.js or NestJS |
| Port | 6101 |

Generates:

```
/var/www/apps/dev/wallet-frontend/
    .env
    deploy.sh
    rollback.sh
```

---

## 📜 deploy.sh (auto-generated)

Automatically:

- Clones latest branch  
- Copies `.env`  
- Runs `npm ci`  
- Builds via Nx  
- Validates output  
- Backs up old version  
- Deploys new version  
- Restarts PM2  
- Reloads Nginx  

---

## 🔁 rollback.sh

Rollback instantly:

```bash
cd /var/www/apps/dev/wallet-frontend
./rollback.sh
```

Restores backup and restarts PM2.

---

## 🔧 Environment File

Generated at:

```
/var/www/apps/dev/<app>/.env
```

Default:

```
NODE_ENV=production
PORT=6101
```

You can add:

```
API_URL=
MONGO_URI=
REDIS_URI=
```

---

## ⚙️ GitHub Actions Integration

Example workflow:

```yaml
name: Deploy Wallet Frontend (Dev)

on:
  push:
    branches: [ dev ]
    paths: [ "apps/wallet-frontend/**" ]

jobs:
  deploy:
    runs-on: [self-hosted, dev-frontend]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: bash /var/www/apps/dev/wallet-frontend/deploy.sh
```

---

## 🧩 When To Use This System

Use PM2 deployment when:

- You run many apps on the same VPS  
- You want simple, fast deployments  
- You don’t want Docker overhead  
- You want auto-build + restart  
- You want per-environment isolation  
- You want quick rollback support  

---

## 📌 When To Switch to Docker

Use `app-deploy-docker/` when:

- You want container isolation  
- You want reproducible builds  
- You want easy scaling  
- You want to move to Kubernetes later  

---

## 🎉 Final Notes

Your PM2 deployment system is now:

- Fully automated  
- Cleanly structured  
- Production safe  
- Easily scalable  
- Perfect for 20–30 apps  

