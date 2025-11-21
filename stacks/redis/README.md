# Redis Stack Deployment
Automated installation of **Redis Stack** in single or multi-port mode with dockerized instances.

---

# 🚀 Features
- Auto install Docker & Compose  
- Auto-generate directories under `/opt/redis-stack-PORT`  
- Auto-generate `redis.conf`  
- Auto-build `.env` per instance  
- Auto replica configuration  
- Automatic UI port (16380, 16381, …)  
- No sudo needed after install  

---

# 📌 Scripts

| Script | Description |
|--------|-------------|
| `setup-instance.sh` | Setup one Redis instance |
| `setup-multiple.sh` | Setup multiple Redis instances |
| `redis-status.sh` | View status of all instances |

Make executable:

```
chmod +x stacks/redis/scripts/*.sh
```

---

# 1️⃣ Create Single Redis Instance

Run:

```
bash stacks/redis/scripts/setup-instance.sh
```

You will be prompted for:

- Redis Port  
- Master or Replica  
- Password  
- (Replica only) Master IP & Port  

Container name:

```
redis-stack-<PORT>
```

Config path:

```
/opt/redis-stack-PORT/conf/redis-PORT.conf
```

---

# 2️⃣ Create Multiple Redis Instances

```
bash stacks/redis/scripts/setup-multiple.sh
```

Prompts:

- Number of ports  
- Starting port  
- Master / Replica  
- Master IP/Port (if replica)  

Each instance gets:

- Its own folder  
- Its own config  
- Its own UI port  
- Auto replica configuration  

---

# 3️⃣ Status of All Redis Instances

```
bash stacks/redis/scripts/redis-status.sh
```

Shows:

- Ping status  
- Role  
- Password  
- Config folder  

---

# 4️⃣ Delete All Redis Instances

```
docker rm -f redis-stack-*
sudo rm -rf /opt/redis-stack-*
docker network ls | grep redis | awk '{print $1}' | xargs docker network rm
```

---

# 🔗 Back to Main Docs

👉 [Main README](../../README.md)

