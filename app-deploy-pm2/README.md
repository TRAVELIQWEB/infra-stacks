# App Deployment System  
### Deploy ANY Frontend / Backend / Worker App using Docker + GHCR

This module allows you to deploy ANY application (Next.js, NestJS, React, Node workers, cron workers, etc.) to any VPS using:

- **GitHub Actions**
- **GHCR (GitHub Container Registry)**
- **Docker Compose**
- **Auto-generated docker-compose.yml + deploy.sh**

---

# 🚀 What This System Does

When you run:

```bash
./scripts/setup-app.sh
```

It automatically:

✓ Creates folder structure  
✓ Creates `docker-compose.yml`  
✓ Creates `deploy.sh`  
✓ Creates env file in `/secrets/`  
✓ Creates global docker network `saarthi-net` (if not exists)  
✓ Ensures Docker + Docker Compose installed  
✓ Ready for GitHub Actions deployment  

---

# 📂 Folder Structure Generated

Example for `wallet-frontend` in **dev**:

```
/var/www/apps/dev/
└── wallet-frontend/
    ├── docker-compose.yml
    ├── deploy.sh
    └── logs/
    
/var/www/apps/dev/secrets/
└── wallet-frontend.env
```

For staging:

```
/var/www/apps/staging/wallet-frontend/
```

For production:

```
/var/www/apps/prod/wallet-frontend/
```

---

# 🛠 How To Deploy a New App (Step-by-Step)

## **1️⃣ Prepare Server (only once)**

```bash
sudo chown -R $USER:$USER /opt
git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra
cd /opt/infra
chmod +x helpers/*.sh
chmod +x app-deploy/scripts/*.sh
```

Docker is auto-installed by script.

---

## **2️⃣ Run Setup Script**

```bash
cd /opt/infra/app-deploy/scripts/
./setup-app.sh
```

The script will ask:

| Question | Example |
|---------|----------|
| App Name | wallet-frontend |
| Environment | dev / staging / prod |
| Server Path | /var/www/apps |
| External Port | 6002 |

---

## **3️⃣ Add Dockerfile + .dockerignore to Your App Repo**

Templates available in:

```
app-deploy/templates/
```

Copy the correct one to your project root:

### Next.js frontend:
```
cp app-deploy/templates/Dockerfile.nextjs ./Dockerfile
```

### NestJS backend:
```
cp app-deploy/templates/Dockerfile.nestjs ./Dockerfile
```

### Worker:
```
cp app-deploy/templates/Dockerfile.worker ./Dockerfile
```

And dockerignore:

```
cp app-deploy/templates/dockerignore.template .dockerignore
```

---

## **4️⃣ Create 3 GitHub Actions Workflows**

Inside your app repo:

```
.github/workflows/
    wallet-frontend-dev.yml
    wallet-frontend-staging.yml
    wallet-frontend-prod.yml
```

Example:

```yaml
name: Dev Deployment (wallet-frontend)

on:
  push:
    branches: [ dev ]
    paths: [ "**/*" ]

jobs:
  build:
    runs-on: [self-hosted, dev-frontend]

    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build Image
        run: docker build -t ghcr.io/traveliqweb/wallet-frontend:dev .

      - name: Push Image
        run: docker push ghcr.io/traveliqweb/wallet-frontend:dev

      - name: Deploy
        run: /var/www/apps/dev/wallet-frontend/deploy.sh
```

---

## **5️⃣ Deploy**

The runner will trigger automatically when you push to the branch.

Or deploy manually:

```bash
cd /var/www/apps/dev/wallet-frontend/
./deploy.sh
```

---

# 🧩 FAQ

### **Where should environments be stored?**
Your apps stay separate — only deployment configs live on the server.

### **Why separate folders for dev/staging/prod?**
Cleaner isolation + easier debugging.

### **Can 50 apps be deployed?**
Yes — structure supports unlimited apps.

---

# 🎉 Done

Your app deployment system is now fully standardized for ALL SaaS products.
