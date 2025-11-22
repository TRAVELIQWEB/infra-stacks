
---

# 🍃 Mongo Backup & Restore System

### Per-Port Automatic Encrypted Daily & Monthly Backups → Zata (S3 Compatible)

This system creates **fully isolated backup flows per MongoDB port**, each with:

* Its own backup directory
* Its own config
* Its own run script
* Its own bucket/folder
* Its own retention policy

Perfect for multi-project servers (wallet, fwms, rail, bus, etc.)

---

# 🚀 Features

| Feature                                     | Supported |
| ------------------------------------------- | --------- |
| Multi Mongo Port Backups (isolated folders) | ✔         |
| Different buckets per port                  | ✔         |
| Different folder prefixes per project       | ✔         |
| Zata S3 / S3 Compatible                     | ✔         |
| GPG Encryption                              | ✔         |
| Daily + Monthly Backups                     | ✔         |
| Automatic Retention                         | ✔         |
| Standalone Restore Script (asks everything) | ✔         |
| Zero Overlap Between Projects               | ✔         |

---

# 📁 Folder Structure (Generated After Setup Script Runs)

```
/opt/mongo-backups/
│
├── 27017/
│   ├── backup-config.env
│   ├── run-mongo-s3-backup.sh
│   └── tmp/
│
├── 27019/
│   ├── backup-config.env
│   ├── run-mongo-s3-backup.sh
│   └── tmp/
│
└── ...
```

⚠ **Restore script is NOT stored per-port.**
You run the standalone restore script from your repo ANYTIME.

---

# 🛠 Setup (Per Port)

Run:

```
bash stacks/mongo-backup/scripts/setup-mongo-s3-backup.sh
```

The script asks for:

* MongoDB port
* Credentials
* Zata endpoint
* Bucket name
* Folder prefix (`wallet`, `fwms`, etc.)
* Encryption password
* Retention settings

Outputs:

```
/opt/mongo-backups/<PORT>/backup-config.env
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh
```

---

# 📅 Cron Jobs (Auto Added Per Port)

Example:

```
/opt/mongo-backups/27017/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27017/run-mongo-s3-backup.sh monthly
```

---

# 🔐 Encryption System

Backups stored as:

```
mongo-<port>-<mode>-<timestamp>.archive.gz.gpg
```

Encrypted with **GPG symmetric password**.

---

# 🧪 Manual Backup

```
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh daily
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh monthly
```

---

# 🗄 Restore Script (Standalone – Asks Everything Every Time)

Run:

```
bash restore-mongo-from-s3.sh
```

The script will ask:

* MongoDB port
* S3 endpoint
* Bucket name
* Folder prefix
* Region
* Access key
* Secret key
* Encryption password
* Restore mode (daily / monthly)
* Backup index
* Target restore host
* Target restore port
* Target restore username/password

✔ 100% independent
✔ No config file required
✔ Safe for emergency restore on ANY server

---

# ⚠ FULL RESTORE MUST RUN ON PRIMARY (MASTER)

MongoDB rule:

* Backup → run on hidden replica
* Restore → run on **PRIMARY** but only **after stepDown()**

---

# ✔️ Full Restore Steps (Correct Workflow)

## **1️⃣ Stop app writes (maintenance mode)**

Avoid inconsistent data.

---

## **2️⃣ Step down the current primary**

Run inside mongo shell:

```
rs.stepDown()
```

Node becomes **SECONDARY** → Safe to restore.

---

## **3️⃣ Run restore script**

```
bash restore-mongo-from-s3.sh
```

The script:

* Lists S3 backups
* Lets you choose backup index
* Downloads file
* Decrypts
* Restores using:

```
mongorestore --archive --gzip --drop
```

---

## **4️⃣ After restore**

Replica set will automatically:

* Elect a new primary
* Sync replicas from restored node
* Become consistent again

No manual replica fixing needed.

---

## **5️⃣ Restart application**

Disable maintenance mode.

---

# 🔄 How Replicas Auto-Heal After Restore

* Secondary nodes detect restored PRIMARY
* Drop local outdated data
* Full-sync
* Cluster becomes consistent

---

# 🛡 Recommended Backup Topology

Add hidden backup replica:

```
rs.add({
  host: "10.50.x.x:<port>",
  hidden: true,
  priority: 0,
  votes: 0
})
```

---

# 🧾 Example Bucket Structures

### Wallet (port 27019)

```
<bucket>
└── wallet
    └── 27019
        ├── daily
        └── monthly
```

### FWMS (port 27017)

```
<bucket>
└── fwms
    └── 27017
        ├── daily
        └── monthly
```

---

# ✅ Final Notes

* Backups run per-port
* Restore script is standalone
* Restore must run on primary after stepDown
* Replica healing is automatic
* Fully isolated multi-project design

---
