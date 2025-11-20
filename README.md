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
    <!-- Port 443 -->
    IdentityFile ~/.ssh/infra-stacks

chmod 600 ~/.ssh/infra-stacks
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh

ssh -T git@github-infra


## System Permissions

Run:

```
sudo chown -R $USER:$USER /opt
```

Example:

```
sudo chown -R sardevops:sardevops /opt
```
 git clone git@github-infra:TRAVELIQWEB/infra-stacks.git /opt/infra
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
  bash stacks/redis/scripts/redis-status.sh

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


## 1. Install Sentinel monitor only

Permissions:

```
chmod +x stacks/sentinel/scripts/setup-sentinel-only.sh
```

Run:

```
bash stacks/sentinel/scripts/setup-sentinel-only.sh
```



## 2. Sentinel Status Dashboard

```
bash stacks/sentinel/scripts/sentinel-status.sh
```

Shows:

- All master groups  
- Replica list  
- Status (UP / DOWN)  
- Failover readiness  

### to make priority  manullly
redis-cli -a "Salman@1004820" -p PORT CONFIG SET replica-priority 0
nano /opt/redis-stack-6380/conf/redis-6380.conf

Add this line:
 replica-priority 0
---


---


---


---

# 🍃 MongoDB 8 Replica Set Setup (Multi-VPS, Multi-Port)

A complete guide for deploying a MongoDB 8 replica set across **multiple VPS servers** using Docker + automation scripts.

Supports:

✔ Multi-VPS replica sets
✔ Multi-port Mongo instances
✔ Keyfile-based internal authentication
✔ Auto configs, auto `.env`, auto directory structure
✔ Mongo 8 (WiredTiger)

---

# 🟢 **ARCHITECTURE**

| VPS      | Purpose                       |
| -------- | ----------------------------- |
| **VPS1** | Master (PRIMARY)              |
| **VPS2** | Replica                       |
| **VPS3** | Replica                       |
| **VPS4** | (Optional) Additional Replica |

All nodes communicate through **NetBird private IPs (10.50.x.x)**.

---
# ✅ 1️⃣ **Setup MASTER MongoDB Instance — VPS1**

Run:

```
bash stacks/mongo/scripts/setup-mongo.sh
```

Enter:

```
Port: 27019
Role: master
Replica Set: walletreplica
Root Username: superuser
Root Password: WalletMongo7861004820
```

When script asks:

```
Initiate replica set now? (y/n)
```

Answer:

```
y
```

You should see:

```
Replica set 'walletreplica' initiated with primary 10.50.0.38:27019
```

## Disable Transparent Huge Pages (THP)
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

## Make it permanent
echo "transparent_hugepage=never" | sudo tee -a /etc/default/grub
sudo update-grub

## Reduce swap usage
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p


### ✔ KeyFile generated:

```
/opt/mongo-keyfile/walletreplica/mongo-keyfile
```

This keyfile MUST be copied to all replica VPS servers.

---

# ✅ 2️⃣ **Prepare VPS2, VPS3, VPS4 (Before running script)**

On each REPLICA VPS run these commands FIRST:

```
sudo mkdir -p /opt/mongo-keyfile
sudo chown -R sardevops:sardevops /opt/mongo-keyfile
sudo chmod 755 /opt/mongo-keyfile
```

---


# ✅ 3️⃣ **Copy KeyFile from MASTER → Replicas**

Run on **VPS1 (Master)**:

```
sudo scp -r /opt/mongo-keyfile/walletreplica \
  sardevops@<REPLICA_NETBIRD_IP>:/opt/mongo-keyfile/
```

Example:

```
sudo scp -r /opt/mongo-keyfile/walletreplica \
  sardevops@10.50.0.227:/opt/mongo-keyfile/
```

Then on each replica VPS:

```
sudo chown -R 999:999 /opt/mongo-keyfile/walletreplica
sudo chmod 600 /opt/mongo-keyfile/walletreplica/mongo-keyfile
```

✔ Makes keyfile readable to MongoDB container
✔ MUST be done before running setup script

---
# ✅ 4️⃣ **Setup Replica VPS Instances (VPS2, VPS3, VPS4)**

Run on each VPS:

```
bash stacks/mongo/scripts/setup-mongo.sh
```

Enter:

```
Port: 27019
Role: replica
Replica Set: walletreplica
Root User: superuser
Root Pass: WalletMongo7861004820
```

Important:

* The script automatically loads the keyfile.
* Replica nodes **do not** initiate RS.

---



# ✅ 5️⃣ **Add Replicas to the MASTER**

SSH into **VPS1 (PRIMARY)**:

```
docker exec -it mongo-27019 mongosh \
  --port 27019 \
  -u superuser \
  -p WalletMongo7861004820 \
  --authenticationDatabase admin

```

Run:

```
rs.add("10.50.0.227:27019")
rs.add("10.50.0.102:27019")
rs.add("10.50.0.103:27019")
```

Then check:

```
rs.status()
```

Expected final:

```
PRIMARY      → 10.50.0.38:27019
SECONDARY    → VPS2
SECONDARY    → VPS3
SECONDARY    → VPS4
```

If replica shows:

```
STARTUP
STARTUP2
RECOVERING
```

This is **normal**. It becomes SECONDARY after sync.

---



# 🟢 **Status Check Script**

Run on any VPS:

```
chmod +x stacks/mongo/scripts/mongo-status.sh

bash stacks/mongo/scripts/mongo-status.sh
```

You will see:

* Port
* Role (master/replica)
* Replica set name
* PRIMARY / SECONDARY
* Auth enabled

---

# 🔥 **COMPLETE REPLICA SET WORKFLOW (SUMMARY)**

1️⃣ Run setup on **MASTER**
2️⃣ Copy keyfile to replicas
3️⃣ Fix keyfile ownership on replicas
4️⃣ Run setup script on replicas
5️⃣ Add replicas from master
6️⃣ Verify using `rs.status()`

---

# 🧹 **Cleanup Commands**

### Delete Mongo Instance

```
docker rm -f mongo-27019
sudo rm -rf /opt/mongo-27019
docker network ls | grep "mongo-27019" | awk '{print $1}' | xargs -r docker network rm
```

To delete keyfile directory:

```
sudo rm -rf /opt/mongo-keyfile
```

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

---
###### deletre all redis
docker ps -a --format '{{.Names}}' | grep 'redis-stack' | xargs -r docker rm -f
docker ps -a --format '{{.Names}}' | grep 'redis-sentinel' | xargs -r docker rm -f

sudo rm -rf /opt/redis-stack-638*
sudo rm -rf /opt/redis-sentinel

sudo rm -rf /opt/redis-stack-*
sudo rm -rf /opt/redis-sentinel-*

docker network ls | grep 'redis-stack' | awk '{print $1}' | xargs -r docker network rm

docker network ls | grep 'sentinel' | awk '{print $1}' | xargs -r docker network rm

docker ps -a
