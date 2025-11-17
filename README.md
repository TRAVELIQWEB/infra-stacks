# infra-stacks

A fully automated infrastructure deployment toolkit for:

- **Redis Stack (Master / Replica / Multi-port)**
- Automatic Docker installation
- Automatic configuration generation
- Per-instance isolated directories
- One-command setup on any server

Designed for scalable deployments across **50+ VPS**, supporting:

- Multiple Redis Stack instances per server
- Master/Replica clusters
- Future Sentinel auto-failover
- Fully automated scripts requiring no manual Docker installation

---

## Repository Structure

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
│   │       └── setup-multiple.sh
│   │
│   └── sentinel/
│       ├── templates/
│       │   ├── sentinel.conf.tpl
│       │   └── sentinel-docker-compose.yml
│       └── scripts/
│           ├── setup-sentinel.sh
│           └── sentinel-status.sh
│
└── README.md
```

---

## Prerequisites

No external prerequisites needed.

### ✔ Auto-installs if missing:

- Docker Engine
- Docker Compose v2
- containerd
- docker-buildx
- docker-model plugin
- Adds user to docker group
- Enables Docker service

---

### github permission
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "infra-stacks-deploy-redis1" -f ~/.ssh/infra-stacks

cat ~/.ssh/infra-stacks.pub

nano ~/.ssh/config

Host github-infra
    HostName github.com
    User git
    IdentityFile ~/.ssh/infra-stacks

chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh

ssh -T git@github-infra


git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra


## System Permissions

Run:

```
sudo chown -R $USER:$USER /opt
```

Example:

```
sudo chown -R sardevops:sardevops /opt
```

---

## Setup Helper Script Permissions

Run once after cloning:

```
chmod +x helpers/io.sh
chmod +x helpers/docker.sh
chmod +x helpers/utils.sh

chmod +x stacks/sentinel/scripts/sentinel-status.sh
```

---

# 🔥 Redis Stack Deployment

Redis Stack is deployed using fully automated scripts.


 ## for status
 /opt/infra/stacks/redis/scripts/sentinel-status.sh

---


## 1. Single Redis Stack Instance

Set permissions:

```
chmod +x stacks/redis/scripts/setup-instance.sh
```

Run:

```
bash stacks/redis/scripts/setup-instance.sh
```

Prompts:

- Redis port  
- Master or Replica  
- Redis password  
- (Replica only) Master IP  
- (Replica only) Master Port  

Creates:

```
/opt/redis-stack-<port>/
    ├── conf/
    ├── data/
    └── .env
```

Starts Docker container:

```
redis-stack-<port>
```

---

## 2. Multiple Redis Stack Instances

Permissions:

```
chmod +x stacks/redis/scripts/setup-multiple.sh
```

Run:

```
bash stacks/redis/scripts/setup-multiple.sh
```

Prompts:

- Number of ports  
- Starting port  
- Master or Replica  
- (If replica) Master IP + Port  

Each instance has:

- Its own config  
- Own UI port (16380, 16381…)  
- Own data directory  
- Auto replica configuration  

---

## Redis Template Permissions

```
chmod 644 stacks/redis/templates/docker-compose.yml
chmod 644 stacks/redis/templates/redis.conf.tpl
```

---

## Redis Script Features

- Auto Docker install  
- Auto docker-compose install  
- Creates isolated instance folders  
- Auto config generator  
- Auto `.env` creator  
- Auto replica setup  
- Auto port allocation  
- No sudo needed after setup  

---

# 🛡️ Redis Sentinel Deployment  
(Auto-Discovery • Auto-Monitoring • Supports 50+ Redis Ports)

Sentinel automatically detects all existing Redis Stack instances under:

```
/opt/redis-stack-*
```

No need to manually configure masters/replicas.

---




## 1. Install Sentinel

Permissions:

```
chmod +x stacks/sentinel/scripts/setup-sentinel.sh
```

Run:

```
bash stacks/sentinel/scripts/setup-sentinel.sh
```

Prompts:

- Sentinel port (default 26379)

Generates config:

```
/opt/redis-sentinel/sentinel-<port>.conf
```

Starts container:

```
redis-sentinel-<port>
```

---



## 2. Sentinel Status Dashboard

```
bash stacks/sentinel/scripts/sentinel-status.sh
```

Shows:

- All master groups  
- Replica list  
- Status (UP / DOWN)  
- Failover readiness  

---

## Multi-VPS Recommended Layout

| VPS | Purpose |
|-----|---------|
| VPS1 | Redis Stack Masters |
| VPS2 | Redis Stack Replicas |
| VPS3 | Redis Stack Replicas |
| VPS4 | Sentinel-only voter |

---


## Script Capabilities

### ✔ Auto-installs Docker  
### ✔ Creates per-instance directories  
### ✔ Generates redis.conf  
### ✔ Creates per-instance `.env`  
### ✔ Maps ports  
### ✔ Starts Redis Stack via docker compose  
### ✔ Appends replicaof for replicas  
### ✔ Prevents duplicate instances  
### ✔ No sudo required  

---

## Coming Next

- Redis Sentinel automation
- Sentinel-only voter node
- MongoDB instance setup
- MongoDB replica sets
- Cleanup tools  
  - remove-instance.sh  
  - remove-multiple.sh  

---

## Support

For help deploying Redis Stack across multiple servers, contact the project owner.

---
