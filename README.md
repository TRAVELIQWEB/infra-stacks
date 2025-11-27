# infra-stacks  
### Automated Redis, Sentinel, MongoDB Replica Sets & Mongo Backup Toolkit

A fully automated infrastructure toolkit for deploying:

- **Redis Stack (single or multi-port)**
- **Redis Sentinel (auto-discovery + monitoring)**
- **MongoDB 8 Replica Sets (multi-VPS, multi-port)**
- **Mongo Backup System (daily + monthly + S3 encrypted backups)**

All services run in **Docker**, auto-configured through scripts.  
Designed for distributed deployments across **50+ VPS servers**.

---

# 📁 Repository Structure

```
infra/
├── helpers/               # Shared utility scripts
│   ├── io.sh
│   ├── docker.sh
│   └── utils.sh
│
├── stacks/
│   ├── redis/             # Redis Stack deployment
│   ├── sentinel/          # Redis Sentinel deployment
│   ├── mongo/             # Mongo Replica deployment
│   └── mongo-backup/      # Mongo Backup (S3 Sync + Encryption + Restore)
│
└── README.md
```

---

# 📚 Documentation (Start Here)

| Component | Documentation |
|----------|---------------|
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

Host github-infra
    HostName github.com
    User git
    IdentityFile ~/.ssh/infra-stacks
```

Permissions:

```
chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
```

Clone:

```
sudo chown -R $USER:$USER /opt
git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra
sudo chown -R $USER:$USER /opt
git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra
```

---

# 🛠 Make Scripts Executable (Run Once After Clone)

```
chmod +x helpers/*.sh
chmod +x stacks/*/scripts/*.sh
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

## 1️⃣ Redis Stack  
- Single/multiple Redis instances  
- Auto-generated configs  
- Replica setup  
- Status dashboard  
📄 `stacks/redis/README.md`

---

## 2️⃣ Redis Sentinel  
- Auto-detect Redis instances  
- Monitors all masters  
- Failover-ready  
- Sentinel-only voter support  
📄 `stacks/sentinel/README.md`

---

## 3️⃣ MongoDB Replica Set  
- Multi-VPS deployment  
- Master + replicas  
- Hidden backup-only node  
- Auto keyfile generation  
📄 `stacks/mongo/README.md`

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
| VPS4 | Sentinel-only voter / Mongo Hidden Backup (backup node) |

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
