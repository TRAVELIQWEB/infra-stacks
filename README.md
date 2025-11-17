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
│   └── redis/
│       ├── templates/
│       │   ├── redis.conf.tpl
│       │   └── docker-compose.yml
│       └── scripts/
│           ├── setup-instance.sh
│           └── setup-multiple.sh
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

## Permissions

Before running any installer:

```bash
sudo chown -R $USER:$USER /opt
```

This allows storing all Redis instances under:

```
/opt/redis-stack-<port>/
```

---

## Setup Helper Script Permissions

Run once after cloning:

```bash
chmod +x helpers/io.sh
chmod +x helpers/docker.sh
chmod +x helpers/utils.sh
```

---

# 🔥 Redis Stack Deployment

Redis Stack is deployed using fully automated scripts.

---

## 1. Single Redis Stack Instance

Set permissions:

```bash
chmod +x stacks/redis/scripts/setup-instance.sh
```

Run:

```bash
bash stacks/redis/scripts/setup-instance.sh
```

You will be asked:

- Redis port (e.g., 6380)
- Master or Replica
- Redis password
- (If replica) Master IP
- (If replica) Master Port

It creates:

```
/opt/redis-stack-<port>/
    ├── conf/
    ├── data/
    └── .env
```

Starts container:

```
redis-stack-<port>
```

---

## 2. Multiple Redis Stack Instances (Auto setup)

Permissions:

```bash
chmod +x stacks/redis/scripts/setup-multiple.sh
```

Run:

```bash
bash stacks/redis/scripts/setup-multiple.sh
```

You will be asked:

- Number of instances (e.g., 6)
- Starting port (e.g., 6380)
- Master or Replica
- (If replica) Master IP
- (If replica) Master Port

Each instance has:

- Independent config
- Independent UI port (16380, 16381, etc.)
- Separate Docker network
- Independent data directory
- Correct replica configuration

---

## Redis Template Permissions

```
chmod 644 stacks/redis/templates/docker-compose.yml
chmod 644 stacks/redis/templates/redis.conf.tpl
```

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
