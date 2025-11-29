
# 🚀 Project Deployment Guide

This project is deployed automatically using:

- **Docker** (containerized runtime)
- **GitHub Actions** (CI/CD pipeline)
- **GitHub Container Registry (GHCR)** (stores Docker images)
- **infra-stacks → setup-app.sh** (server-side setup automation)

All deployments are consistent across **dev → staging → prod**.

---

# 📁 Required Files Inside This Project

Every application **must contain**:

```
Dockerfile
.dockerignore
```

Use the templates from:

```
infra-stacks/app-deploy/templates/
```

Copy to your app:

```bash
cp /opt/infra/app-deploy/templates/Dockerfile.nextjs ./Dockerfile
cp /opt/infra/app-deploy/templates/dockerignore.template .dockerignore
```

You may replace `Dockerfile.nextjs` with:

| App Type     | Template File          |
|--------------|-------------------------|
| Next.js      | Dockerfile.nextjs       |
| NestJS API   | Dockerfile.nestjs       |
| Worker/Cron  | Dockerfile.worker       |
| React/Vite   | Dockerfile.react        |

---

# 🛠 How Deployment Works

## 1. GitHub Actions builds the Docker image

Whenever you push to:

- `dev` → Deploy to **Dev VPS**
- `staging` → Deploy to **Staging VPS**
- `main` → Deploy to **Production VPS**

The workflow:

1. Builds image using your Dockerfile  
2. Tags it as:

```
ghcr.io/<org>/<app-name>:dev
ghcr.io/<org>/<app-name>:staging
ghcr.io/<org>/<app-name>:prod
```

3. Pushes it to GHCR  
4. Triggers deployment on the server runner  

---

## 2. Server setup using infra-stacks (`setup-app.sh`)

On the target server:

```bash
cd /opt/infra/app-deploy/scripts
./setup-app.sh
```

Script asks:

```
App name:
Environment (dev/staging/prod):
Server folder (/opt/apps or /var/www/apps):
External port (e.g., 6002):
```

This script creates folder structure:

```
/opt/apps/dev/<app-name>/
   ├── docker-compose.yml
   ├── deploy.sh
   ├── secrets/<app-name>.env
   └── logs/
```

Now the server is ready to receive deployments.

---

## 3. Deployment happens automatically

Each environment has a runner tag:

| Environment | Runner Label |
|------------|---------------|
| Dev        | dev-frontend, dev-backend |
| Staging    | staging-frontend, staging-backend |
| Prod       | prod-frontend, prod-backend |

Your workflow:

```
runs-on: [self-hosted, dev-frontend]
```

Then the pipeline runs:

```bash
cd /opt/apps/dev/<app-name>
./deploy.sh
```

---

# 🔐 Environment Variables

Secrets are kept **on the server**, not in GitHub.

Paths:

```
/opt/apps/dev/secrets/<app-name>.env
/opt/apps/staging/secrets/<app-name>.env
/opt/apps/prod/secrets/<app-name>.env
```

---

# ✔ Local Development

```
npm install
npm run dev
npm run build
```

---

# 🐳 Local Docker Testing

```
docker build -t <app-name>:local .
docker run -p 3000:3000 <app-name>:local
```

---

# 📦 Workflow Naming Convention

```
wallet-frontend-dev.yml
wallet-frontend-staging.yml
wallet-frontend-prod.yml
```

---

# 📡 Logs & Debugging

```
docker logs <container> -f
docker ps
./deploy.sh
```

---

# 📝 Save this file as: README_DEPLOY.md
