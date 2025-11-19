# infra-stacks

A fully automated infrastructure deployment toolkit for:

- **Redis Stack (Master / Replica / Multi-port)**
- **Redis Sentinel (Auto-Discovery / Auto-Monitoring)**
- **MongoDB 8 (Standalone / Replica Set / Multi-port)**
- **Automatic Docker Installation**
- **Automatic Configuration Generation**
- **Per-Instance Isolated Directories**
- **One-Command Setup on Any Server**

Designed for scalable deployments across **50+ VPS**, supporting:

- Multiple Redis Stack instances per server  
- Multiple MongoDB instances per server  
- Master/Replica/Replica-Set architectures  
- Sentinel-based failover  
- Zero-manual-configuration automation  

---

# 📁 Repository Structure

```
infra/
├── helpers/
│   ├── io.sh
│   ├── docker.sh
│   └── utils.sh
│
├── stacks/
│   ├── redis/
│   │   ├── templates/
│   │   │   ├── redis.conf.tpl
│   │   │   └── docker-compose.yml
│   │   └── scripts/
│   │       ├── setup-instance.sh
│   │       ├── setup-multiple.sh
│   │       └── redis-status.sh
│   │
│   ├── sentinel/
│   │   ├── templates/
│   │   │   ├── sentinel.conf.tpl
│   │   │   └── sentinel-docker-compose.yml
│   │   └── scripts/
│   │       ├── setup-sentinel.sh
│   │       └── sentinel-status.sh
│   │
│   └── mongo/
│       ├── templates/
│       │   ├── mongod.conf.tpl
│       │   └── docker-compose.yml
│       └── scripts/
│           ├── setup-mongo.sh
│           └── mongo-status.sh
│
└── README.md
```

---
# 🧰 Prerequisites

No prerequisites required.  
The system **auto-installs**:

- Docker Engine  
- Docker Compose v2  
- containerd  
- buildx plugin  
- docker-cli plugins  
- Adds user to docker group  
- Enables Docker daemon  

---


# 🔑 GitHub SSH Setup

```
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "infra-stacks-deploy" -f ~/.ssh/infra-stacks
cat ~/.ssh/infra-stacks.pub
```

Configure SSH:

```
nano ~/.ssh/config

Host github-infra
    HostName github.com
    User git
    IdentityFile ~/.ssh/infra-stacks
```

Secure permissions:

```
chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh
```

Test:

```
ssh -T git@github-infra
```

Clone repo:

```
git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra
```

---

# 👤 Permissions

```
sudo chown -R $USER:$USER /opt
```

Example:

```
sudo chown -R sardevops:sardevops /opt
```

---

# ⚙️ Helper Script Permissions

```
chmod +x helpers/io.sh
chmod +x helpers/docker.sh
chmod +x helpers/utils.sh
```

---

---


# 🔥 Redis Stack Deployment

## ✔ Redis Status

```
bash stacks/redis/scripts/redis-status.sh
```

---

## 1️⃣ Single Redis Stack Instance

```
chmod +x stacks/redis/scripts/setup-instance.sh
bash stacks/redis/scripts/setup-instance.sh
```

Prompts:

- Redis port  
- Master or Replica  
- Password  
- (Replica) Master IP + Port  

---

## 2️⃣ Multiple Redis Stack Instances

```
chmod +x stacks/redis/scripts/setup-multiple.sh
bash stacks/redis/scripts/setup-multiple.sh
```

Prompts:

- How many instances  
- Starting port  
- Master/Replica  
- (Replica) Master IP  

Each instance gets:

- Unique data directory  
- Unique UI port (16380+)  
- Auto-generated configuration  
- Auto replica linking  

---

# 🛡 Redis Sentinel Deployment  
(One sentinel per VPS)

## 1️⃣ Install Sentinel

```
chmod +x stacks/sentinel/scripts/setup-sentinel.sh
bash stacks/sentinel/scripts/setup-sentinel.sh
```

Prompts:

- Sentinel port (default: 26379)

Scans all Redis instances under `/opt/redis-stack-*`  
Automatically configures monitors.

---

## 2️⃣ Sentinel Status Dashboard

```
bash stacks/sentinel/scripts/sentinel-status.sh
```

Shows:

- Master nodes  
- Replica list  
- Failover readiness  
- Flags, epoch, quorum  

---

### Set replica priority manually

```
redis-cli -a "<PASS>" -p <PORT> CONFIG SET replica-priority 0
```

File level:

```
nano /opt/redis-stack-6380/conf/redis-6380.conf
replica-priority 0
```

---

# 🍃 MongoDB 8 Deployment  
(Standalone / Replica Set / Multi-Instance)

Mongo automation supports:

- Multiple MongoDB instances per VPS  
- Auto-created config  
- Auto keyFile generation (internal auth)  
- Auto replica set initiation  
- Username/password creation  
- `mongo:8` Docker image  

---

## 1️⃣ Setup MongoDB Instance

```
chmod +x stacks/mongo/scripts/setup-mongo.sh
bash stacks/mongo/scripts/setup-mongo.sh
```

Prompts:

- MongoDB port  
- Master or Replica  
- Replica set name  
- Root username  
- Root password (auto-generate supported)  

Creates:

- `/opt/mongo-PORT/`  
- `mongod.conf`  
- `.env`  
- Shared keyFile  
- Docker Compose container  

If role = master → optional **replica-set initiation**.

---

## ✔ MongoDB Status

```
bash stacks/mongo/scripts/mongo-status.sh
```

Shows:

- Port  
- Role  
- ReplicaSet Name  
- PRIMARY / SECONDARY  
- Auth status  

---

# 📦 Recommended VPS Layout

| VPS | Purpose |
|-----|---------|
| VPS1 | Redis Masters + Mongo Primary |
| VPS2 | Redis Replicas + Mongo Secondary |
| VPS3 | Redis Replicas + Mongo Secondary |
| VPS4 | Sentinel-only voter |

---

# 🧹 Full Cleanup (Redis + Sentinel)

```
docker ps -a --format '{{.Names}}' | grep 'redis-stack' | xargs -r docker rm -f
docker ps -a --format '{{.Names}}' | grep 'redis-sentinel' | xargs -r docker rm -f

sudo rm -rf /opt/redis-stack-*
sudo rm -rf /opt/redis-sentinel*

docker network ls | grep 'redis-stack' | awk '{print $1}' | xargs -r docker network rm
docker network ls | grep 'sentinel' | awk '{print $1}' | xargs -r docker network rm
docker ps -a
```

---

# 📞 Support

For deployment help or custom infrastructure automation, contact the project owner.
