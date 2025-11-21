



---

# 🍃 Mongo Backup & Restore System

### Per-Port Automatic Encrypted Daily & Monthly Backups → Zata (S3 Compatible)

This system **creates a completely isolated backup setup per MongoDB port**, each with:

* Its own backup directory
* Its own config file
* Its own run script
* Its own restore script
* Its own bucket or folder
* Its own retention policy

Perfect for multi-project servers (wallet, fwms, rail, bus, etc.)

---

# 🚀 Features

| Feature                                     | Supported |
| ------------------------------------------- | --------- |
| Multi Mongo Port Backups (isolated folders) | ✔         |
| Different buckets for each port             | ✔         |
| Different folder prefixes per project       | ✔         |
| Zata S3 / S3 Compatible                     | ✔         |
| Encryption (GPG symmetric)                  | ✔         |
| Daily Backups                               | ✔         |
| Monthly Backups                             | ✔         |
| Per-port retention cleanup                  | ✔         |
| Auto cron setup                             | ✔         |
| Fully isolated restore script per port      | ✔         |
| Zero mixing between projects                | ✔         |

---

# 📁 New File Structure (Per-Port Architecture)

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

This means:

* Wallet DB → own bucket/folder
* FWMS DB → own bucket/folder
* Rail DB → own bucket/folder
* Bus DB → own bucket/folder

**No interference between systems.**

---

# 🛠 Setup

Run:

```
bash stacks/mongo-backup/scripts/setup-mongo-s3-backup.sh
```

You will be asked:

* MongoDB port
* Username / password / auth DB
* Zata endpoint
* Bucket name (you can use different bucket for each port)
* Folder prefix (wallet / fwms / rail / bus…)
* GPG encryption password
* Retention settings

This generates:

```
/opt/mongo-backups/<PORT>/backup-config.env
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh
/opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

Each port becomes an **independent backup system**.

---

# 📅 Cron Jobs (Per Port)

Example for port **27017**:

```
/opt/mongo-backups/27017/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27017/run-mongo-s3-backup.sh monthly
```

Example for port **27019**:

```
/opt/mongo-backups/27019/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27019/run-mongo-s3-backup.sh monthly
```

---

# 🧪 Manual Run

For port 27017:

```
/opt/mongo-backups/27017/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27017/run-mongo-s3-backup.sh monthly
```

For port 27019:

```
/opt/mongo-backups/27019/run-mongo-s3-backup.sh daily
/opt/mongo-backups/27019/run-mongo-s3-backup.sh monthly
```

---

# 🔐 Encryption

Each dump is encrypted using GPG symmetric encryption:

```
mongo-<port>-<mode>-<timestamp>.archive.gz.gpg
```

Restorable only with the same passphrase.

---

# 🗄 Restore Script (Per Port)

Each port has its own restore script:

```
bash /opt/mongo-backups/<PORT>/restore-mongo-from-s3.sh
```

Restore Flow:

1. Choose daily / monthly
2. Script lists backups from:

   ```
   s3://<bucket>/<prefix>/<port>/<daily|monthly>/
   ```
3. Select backup index
4. Download
5. Decrypt
6. Extract
7. Restore via mongorestore

---

# 🧹 Retention Cleanup

Each port maintains its own retention:

### Daily

```
DAILY_RETENTION = 10 (default)
```

### Monthly

```
MONTHLY_RETENTION = 6 (default)
```

Oldest backups are deleted automatically per port.

---

# 🛡 Recommended: Use Hidden Replica for Backups

Always back up from hidden node:

```
priority: 0
votes: 0
hidden: true
```

Configure:

```
rs.add({
  host: "10.50.x.x:<port>",
  hidden: true,
  priority: 0,
  votes: 0
})
```

Benefits:

* Zero load on primary
* Backups do not slow down production
* Safe, consistent snapshots

---

# 🧾 Example Bucket Structure

### Wallet DB (port 27019)

```
saarmongobackups
└── wallet
    └── 27019
        ├── daily
        └── monthly
```

### FWMS DB (port 27017)

```
saarmongobackups
└── fwms
    └── 27017
        ├── daily
        └── monthly
```

---
