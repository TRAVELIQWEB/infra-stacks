# 🍃 Mongo Backup & Restore System
### Per-Port Automatic Encrypted Daily & Monthly Backups → Zata (S3 Compatible)

This system **creates a completely isolated backup setup per MongoDB port**, each with:

- Its own backup directory  
- Its own config file  
- Its own run script  
- Its own restore script  
- Its own bucket or folder  
- Its own retention policy  

Perfect for multi-project servers (wallet, fwms, rail, bus, etc.)

---

# 🚀 Features

| Feature                                     | Supported |
|---------------------------------------------|-----------|
| Multi Mongo Port Backups (isolated folders) | ✔ |
| Different buckets for each port             | ✔ |
| Different folder prefixes per project       | ✔ |
| Zata S3 / S3 Compatible                     | ✔ |
| Encryption (GPG symmetric)                  | ✔ |
| Daily Backups                               | ✔ |
| Monthly Backups                             | ✔ |
| Per-port retention cleanup                  | ✔ |
| Auto cron setup                             | ✔ |
| Fully isolated restore script per port      | ✔ |
| Zero mixing between projects                | ✔ |

---

# 📁 Per-Port Directory Structure

Every Mongo port gets its own directory:

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

This means each DB has full isolation.

---

# 🛠 Setup

Run:

```
bash stacks/mongo-backup/scripts/setup-mongo-s3-backup.sh
```

You will be asked:

- MongoDB port  
- Username / password / auth DB  
- Zata endpoint  
- Bucket name  
- Folder prefix (wallet / fwms / rail / bus)  
- GPG encryption password  
- Retention settings  

This generates:

```
/opt/mongo-backups/<PORT>/backup-config.env
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh
/opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

Each port becomes an independent backup system.

---

# 📅 Cron Jobs (Per Port)

Examples:

Port 27017:

```
/opt/mongo-backups/27017/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27017/run-mongo-s3-backup.sh monthly
```

Port 27019:

```
/opt/mongo-backups/27019/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27019/run-mongo-s3-backup.sh monthly
```

---

# 🧪 Manual Run

Daily backup:

```
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh daily
```

Monthly backup:

```
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh monthly
```

---

# 🔐 Encryption

Each dump is encrypted using GPG symmetric encryption:

```
mongo-<port>-<mode>-<timestamp>.archive.gz.gpg
```

Only decryptable with your passphrase.

---

# 🗄 Restore Script (Per Port)

Each port has its own restore script:

```
bash /opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

---

# ⚠️ Restore MUST BE Executed on PRIMARY (Master Node)

To safely restore:

---

# ✔️ Full Restore Steps

## 1️⃣ Stop application writes  
Enable maintenance mode.

---

## 2️⃣ Step down primary to allow restore

```
mongo
rs.stepDown()
```

This converts the primary into a secondary—MongoDB allows restore only on non-primary state.

---

## 3️⃣ Run the restore script

```
bash /opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

The script will:

- Ask daily/monthly  
- Show backup list  
- Download  
- Decrypt  
- Restore using:

```
mongorestore --archive --gzip --drop
```

---

## 4️⃣ After restore, the node rejoins the replica set

MongoDB will automatically:

- Elect a primary  
- Sync other replicas  
- Heal the replica set automatically  

Nothing manual required.

---

## 5️⃣ Start application again

Disable maintenance mode.

---

# 🔄 How Replicas Sync After Restore

After restore completes on master:

- Other replicas automatically drop old data  
- Perform full sync from the restored node  
- Become consistent without any manual operations  

---

# 🧾 Example Bucket Structure

Wallet DB (27019):

```
saarmongobackups
└── wallet
    └── 27019
        ├── daily
        └── monthly
```

FWMS DB (27017):

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
- Replication auto-recovers  
- Each port is fully isolated  
