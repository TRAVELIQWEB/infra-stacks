# Redis Sentinel Deployment
Automatically deploy Redis Sentinel with auto-discovery of Redis Stack instances.

---

# 🚀 Features
- Auto-detects all Redis instances under `/opt/redis-stack-*`  
- Auto-maps master/replica groups  
- No manual configuration needed  
- Supports Sentinel-only voter node  
- Full status dashboard  

---

# 📌 Scripts

| Script | Description |
|--------|-------------|
| `setup-sentinel.sh` | Install Sentinel on Redis+Sentinel VPS |
| `setup-sentinel-only.sh` | Install Sentinel on voter-only VPS |
| `sentinel-status.sh` | Sentinel monitoring dashboard |

Make executable:

```
chmod +x stacks/sentinel/scripts/*.sh
```

---

# 1️⃣ Install Sentinel (Normal VPS)

```
bash stacks/sentinel/scripts/setup-sentinel.sh
```

Prompts:

- Sentinel port (default 26379)

Creates:

```
/opt/redis-sentinel/sentinel-PORT.conf
```

Starts container:

```
redis-sentinel-PORT
```

---

# 2️⃣ Install Sentinel-Only (Voting Node)

```
bash stacks/sentinel/scripts/setup-sentinel-only.sh
```

Ideal for **VPS4** or any node without Redis.

---

# 3️⃣ View Sentinel Dashboard

```
bash stacks/sentinel/scripts/sentinel-status.sh
```

Shows:

- Master groups  
- Replicas  
- Failover readiness  
- UP/DOWN status  

---

# 🔧 Manually Change Replica Priority

```
redis-cli -a PASSWORD -p PORT CONFIG SET replica-priority 0
```

Edit:

```
nano /opt/redis-stack-PORT/conf/redis-PORT.conf
```

---

# 🔗 Back to Main Docs

👉 [Main README](../../README.md)

