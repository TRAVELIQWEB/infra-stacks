# MongoDB 8 Replica Set Deployment
Automated multi-VPS MongoDB 8 replica set setup using Docker & Bash scripts.

---

# 🚀 Features
- Auto Docker install  
- Auto keyfile generation  
- Auto docker-compose  
- Multi-port support  
- Master + replicas + hidden backup node  
- Status dashboard  

---

# 📌 Scripts

| Script | Description |
|--------|-------------|
| `setup-mongo.sh` | Setup Mongo master or replica |
| `mongo-status.sh` | Check Mongo mode (PRIMARY/SECONDARY) |

Make executable:

```
chmod +x stacks/mongo/scripts/*.sh
```

---

# 1️⃣ Setup MASTER Node

```
bash stacks/mongo/scripts/setup-mongo.sh
```

Enter:

- Port  
- Role: `master`  
- Replica set name  
- Root username  
- Root password  

Script generates keyfile at:

```
/opt/mongo-keyfile/<replicaset>/mongo-keyfile
```

Then initiates:

```
rs.initiate()
```

---

# 2️⃣ Prepare Replica VPS (Before running script)

```
sudo mkdir -p /opt/mongo-keyfile
sudo chown -R $USER:$USER /opt/mongo-keyfile
sudo chmod 755 /opt/mongo-keyfile
```

---

# 3️⃣ Copy KeyFile to Replica Nodes

From MASTER:

```
sudo scp -r /opt/mongo-keyfile/<replicaset> \
  user@10.50.x.x:/opt/mongo-keyfile/
```

On each replica:

```
sudo chown -R 999:999 /opt/mongo-keyfile/<replicaset>
sudo chmod 600 /opt/mongo-keyfile/<replicaset>/mongo-keyfile
```

---

# 4️⃣ Setup Replica Nodes

Run:

```
bash stacks/mongo/scripts/setup-mongo.sh
```

Choose:

- Role: `replica`  
- Same replica set name  
- Same root credentials  

---

# 5️⃣ Add Replicas from MASTER

Log into master:

```
docker exec -it mongo-PORT mongosh -u root -p pass --authenticationDatabase admin
```

Add:

```
rs.add("10.50.0.227:27019")
rs.add("10.50.0.102:27019")
```

---

# 6️⃣ Add Hidden Backup Node

```
rs.add({
  host: "10.50.x.x:PORT",
  priority: 0,
  hidden: true,
  votes: 0
})
```

---

# 7️⃣ Check Status

```
bash stacks/mongo/scripts/mongo-status.sh
```

---

# 🔧 Recommended Kernel Tweaks

```
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```

---

# 🔗 Back to Main Docs

👉 [Main README](../../README.md)

