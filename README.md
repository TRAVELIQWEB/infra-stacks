# infra-stacks  
### Automated Redis, Sentinel & MongoDB Deployment Toolkit

A fully automated infrastructure toolkit for deploying:

- **Redis Stack (single or multi-port)**
- **Redis Sentinel (auto-discovery + monitoring)**
- **MongoDB 8 Replica Sets (multi-VPS, multi-port)**

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
│   └── mongo/             # Mongo Replica deployment
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

```
chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
```

Test:

```
ssh -T git@github-infra
```

Clone repo:

```
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
No need to install Docker manually — scripts automatically:

- Install Docker Engine  
- Install Docker Compose v2  
- Enable docker service  
- Add user to docker group  

---

# 🎯 Modules Overview

## 1️⃣ Redis Stack  
- Single or multiple Redis instances  
- Auto replica configuration  
- UI port exposure  
- Auto directory creation  
- Status scripts  

📄 **Docs:** `stacks/redis/README.md`

---

## 2️⃣ Redis Sentinel  
- Auto-detects all Redis Stack instances  
- Auto monitors masters & replicas  
- Failover readiness dashboard  
- Sentinel-only voting node support  

📄 **Docs:** `stacks/sentinel/README.md`

---

## 3️⃣ MongoDB 8 Replica Set  
- Multi-VPS deployment  
- Master + replicas + hidden backup node  
- Auto keyfile generation  
- Auto docker-compose  
- Status checker  

📄 **Docs:** `stacks/mongo/README.md`

---

# ✔ Recommended Layout

| VPS | Purpose |
|-----|---------|
| VPS1 | Redis Masters / Mongo Primary |
| VPS2 | Redis Replicas / Mongo Secondary |
| VPS3 | Redis Replicas / Mongo Secondary |
| VPS4 | Sentinel-only voter / Mongo Hidden Backup |

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
Now check individual module READMEs for exact workflows.

