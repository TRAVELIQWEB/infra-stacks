# 🍃 Mongo Backup & Restore System

### Per-Port Automatic Encrypted Daily & Monthly Backups → Zata (S3 Compatible)

This system creates **fully isolated backup + restore flows per MongoDB port**, each with:

- Its own backup directory  
- Its own config  
- Its own run script  
- Its own restore script  
- Its own bucket/folder  
- Its own retention policy  

Perfect for multi‑project servers (wallet, fwms, rail, bus, etc.)

---

# 🚀 Features

| Feature | Supported |
|--------|-----------|
| Multi Mongo Port Backups (isolated folders) | ✔ |
| Different buckets for each port | ✔ |
| Different folder prefixes per project | ✔ |
| Zata S3 / S3 Compatible | ✔ |
| GPG Encryption | ✔ |
| Daily + Monthly Backups | ✔ |
| Automatic Retention | ✔ |
| Per-Port Restore Scripts | ✔ |
| Zero Overlapping Between Projects | ✔ |

---

# 📁 Folder Structure

```
/opt/mongo-backups/
│
├── 27017/
│   ├── backup-config.env
│   ├── run-mongo-s3-backup.sh
│   ├── restore-mongo-from-s3.sh
│   └── tmp/
│
├── 27019/
│   ├── backup-config.env
│   ├── run-mongo-s3-backup.sh
│   ├── restore-mongo-from-s3.sh
│   └── tmp/
│
└── ...
```

Each port = completely isolated backup environment.

---

# 🛠 Setup

Run:

```
bash stacks/mongo-backup/scripts/setup-mongo-s3-backup.sh
```

Setup asks for:

- MongoDB port  
- Credentials  
- Zata endpoint  
- Bucket name (different bucket allowed per port)  
- Folder prefix (`wallet`, `fwms`, etc.)  
- Encryption password  
- Retention settings  

This generates three files for that port:

```
/opt/mongo-backups/<PORT>/backup-config.env
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh
/opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

---

# 📅 Cron Jobs (Per Port)

Example for **27017**:

```
/opt/mongo-backups/27017/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27017/run-mongo-s3-backup.sh monthly
```

Example for **27019**:

```
/opt/mongo-backups/27019/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27019/run-mongo-s3-backup.sh monthly
```

---

# 🔐 Encryption

Backups are stored as encrypted files:

```
mongo-<port>-<mode>-<timestamp>.archive.gz.gpg
```

---

# 🧪 Manual Backup

```
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh daily
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh monthly
```

---

# 🗄 Restore Script (Per Port)

Run:

```
bash /opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

---

# ⚠ FULL RESTORE MUST RUN ON PRIMARY (MASTER)

MongoDB architecture:

- Backup recommended on hidden replica  
- Restore must run on **PRIMARY**, but after **stepDown**  

---

# ✔️ Full Restore Steps (FINAL & CORRECT)

## **1️⃣ Stop application writes**

Enable maintenance mode.

---

## **2️⃣ Step down the primary**

Run this on master:

```
mongo
rs.stepDown()
```

This converts primary → secondary, now safe to restore.

Reconnect example:

```
docker exec -it mongo-<PORT> mongosh   --port <PORT>   -u <USER>   -p <PASSWORD>   --authenticationDatabase admin
```

---

## **3️⃣ Run the restore script**

```
bash /opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

Script performs:

- Ask daily/monthly  
- List backups  
- Download  
- Decrypt  
- Restore using:

```
mongorestore --archive --gzip --drop
```

---

## **4️⃣ After restore completes**

MongoDB automatically:

- Rejoins replica set  
- Elects a primary  
- Syncs all replicas from restored node  

---

## **5️⃣ Start application again**

Disable maintenance mode.

---

# 🔄 How Replicas Sync After Restore

- Other replicas drop old data  
- Perform full initial sync  
- Automatically become consistent  

No manual work needed.

---

# 🛡 Recommended Backup Topology

Use hidden replica:

```
rs.add({
  host: "10.50.x.x:<port>",
  hidden: true,
  priority: 0,
  votes: 0
})
```

---

# 🧾 Example Bucket Structure

### Wallet DB (port **27019**)

```
saarmongobackups
└── wallet
    └── 27019
        ├── daily
        └── monthly
```

### FWMS DB (port **27017**)

```
saarmongobackups
└── fwms
    └── 27017
        ├── daily
        └── monthly
```

---

# ✅ Final Notes

- Backups should run on hidden replica  
- Restore must run on master after stepDown  
- Replication auto-heals  
- Fully isolated per-port system  
