# infra-stacks  
### Automated Redis, Sentinel, MongoDB Replica Sets & Mongo Backup Toolkit

A fully automated infrastructure toolkit for deploying:

- **Redis Stack (single or multi-port)**
- **Redis Sentinel (auto-discovery + monitoring)**
- **MongoDB 8 Replica Sets (multi-VPS, multi-port)**
- **Mongo Backup System (daily + monthly + S3 encrypted backups)**
- **ANY Frontend / Backend App Deployment via Docker + GHCR (NEW)**

All services run in **Docker**, auto-configured through scripts.  
Designed for distributed deployments across **50+ VPS servers**.

---

# 📁 Repository Structure

```
infra/
├── helpers/                 # Shared utility scripts
│   ├── io.sh
│   ├── docker.sh
│   └── utils.sh
│
├── app-deploy/              # ⭐ NEW: Deploy any frontend/backend (Next.js, NestJS, Workers)
│   ├── scripts/
│   │   └── setup-app.sh     # Auto-generates docker-compose.yml + deploy.sh
│   ├── templates/           # Dockerfile & dockerignore templates
│   └── README.md            # Full documentation for app deployment
│
├── stacks/
│   ├── redis/               # Redis Stack deployment
│   ├── sentinel/            # Redis Sentinel deployment
│   ├── mongo/               # Mongo Replica deployment
│   └── mongo-backup/        # Mongo Backup (S3 Sync + Encryption + Restore)
│
└── README.md
```

---

# 📚 Documentation (Start Here)

| Component | Documentation |
|----------|---------------|
| **App Deployment (Frontend/Backend)** | 👉 [`app-deploy/README.md`](app-deploy-pm2/README.md) |
| **Redis Stack** | 👉 [`stacks/redis/README.md`](stacks/redis/README.md) |
| **Redis Sentinel** | 👉 [`stacks/sentinel/README.md`](stacks/sentinel/README.md) |
| **Mongo Replica Set** | 👉 [`stacks/mongo/README.md`](stacks/mongo/README.md) |
| **Mongo Backup System** | 👉 [`stacks/mongo-backup/README.md`](stacks/mongo-backup/README.md) |

---

# 🔑 Clone Using SSH

```
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "infra-stacks-deploy" -f ~/.ssh/infra-stacks
cat ~/.ssh/infra-stacks.pub
```

**SSH config:**

```
nano ~/.ssh/config

# ===========================
# infra-stacks (Infra Repo)
# ===========================

# Repo: infra-stacks
Host infra-stacks
    HostName ssh.github.com
    User git
    Port 443
    IdentityFile ~/.ssh/infra-stacks
    IdentitiesOnly yes
    StrictHostKeyChecking no

```

Permissions:

```
chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
```

Clone:

```
sudo chown -R $USER:$USER /opt
git clone git@infra-stacks:TRAVELIQWEB/infra-stacks.git /opt/infra

```

---

# 🛠 Make Scripts Executable (Run Once After Clone)

```
chmod +x helpers/*.sh
chmod +x stacks/*/scripts/*.sh
chmod +x app-deploy-pm2/scripts/*.sh
chmod +x app-deploy-docker/scripts/*.sh

```

---

# 🐳 Docker & Compose Auto-Install  
No manual installation needed. Scripts handle:

- Docker Engine  
- Docker Compose v2  
- containerd  
- docker group permissions  
- docker service enable  

---

# 🎯 Modules Overview

## 1️⃣ App Deployment (NEW)
- Deploy **any new app** (frontend/backend/workers)
- Auto create:
  - `docker-compose.yml`
  - `deploy.sh`
  - env file in `/secrets`
- Uses GHCR images automatically
📄 `app-deploy/README.md`


## 2️⃣ Redis Stack  
- Single/multi Redis  
- Auto-generated configs  
📄 `stacks/redis/README.md`

---

## 3️⃣ Redis Sentinel  
- Auto-monitor master nodes  
📄 `stacks/sentinel/README.md`

---

## 4️⃣ MongoDB Replica Sets  
📄 `stacks/mongo/README.md`

## 5️⃣ Mongo Backup System  
📄 `stacks/mongo-backup/README.md`

---

## 4️⃣ Mongo Backup System (Daily + Monthly + S3)  
- Runs on hidden replica (backup node)  
- Daily & monthly encrypted backups  
- Zata S3 compatible  
- Automatic retention cleanup  
- Full restore script included  
📄 `stacks/mongo-backup/README.md`

---

# ✔ Recommended Layout

| VPS | Purpose |
|-----|---------|
| VPS1 | Redis Masters / Mongo Primary |
| VPS2 | Redis Replicas / Mongo Secondary |
| VPS3 | Redis Replicas / Mongo Secondary |
| VPS4 | Sentinel + Mongo Hidden Backup |


---

# 🧹 Cleanup Utilities (All Redis)

```
docker ps -a --format '{{.Names}}' | grep 'redis-stack' | xargs -r docker rm -f
docker ps -a --format '{{.Names}}' | grep 'redis-sentinel' | xargs -r docker rm -f

sudo rm -rf /opt/redis-stack-*
sudo rm -rf /opt/redis-sentinel*

docker network ls | grep 'redis' | awk '{print $1}' | xargs -r docker network rm
docker network ls | grep 'sentinel' | awk '{print $1}' | xargs -r docker network rm
```

---

# 🎉 Done  
Refer to each module’s README for exact setup flows.
