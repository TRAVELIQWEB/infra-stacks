# 🍃 Mongo Backup & Restore System

### Per-Port Automatic Encrypted Daily & Monthly Backups → Zata (S3 Compatible)

This system creates **fully isolated backup flows per MongoDB port**, each with:

* Its own backup directory
* Its own config
* Its own run script
* Its own bucket/folder
* Its own retention policy
* Its own log files

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
| Automatic Log File Creation                 | ✔         |
| Version Conflict Handling                   | ✔         |
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

**Log Files Location:**
```
/var/log/
├── mongo-backup-27017-daily.log
├── mongo-backup-27017-monthly.log
├── mongo-backup-27019-daily.log
└── mongo-backup-27019-monthly.log
```

⚠ **Restore script is NOT stored per-port.**
You run the standalone restore script from your repo ANYTIME.

---

# 🛠 Setup (Per Port)

Run:

```bash
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

**Automatically Creates:**
- Backup directory structure
- Config files
- Backup scripts
- **Log files with proper permissions**
- Cron jobs

**Outputs:**
```
/opt/mongo-backups/<PORT>/backup-config.env
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh
/var/log/mongo-backup-<PORT>-daily.log
/var/log/mongo-backup-<PORT>-monthly.log
```

---

# 📅 Cron Jobs (Auto Added Per Port)

**Production Schedule:**
- Daily: `30 2 * * *` (2:30 AM every day)
- Monthly: `0 3 1 * *` (3:00 AM on 1st of each month)

**Log Location:**
- Daily logs: `/var/log/mongo-backup-<PORT>-daily.log`
- Monthly logs: `/var/log/mongo-backup-<PORT>-monthly.log`

**Safe Re-run:**
- Re-running for same port **replaces** existing cron jobs
- Different ports remain **unaffected**
- Other system cron jobs **preserved**

---

# 🔐 Encryption System

Backups stored as:
```
mongo-<port>-<mode>-<timestamp>.archive.gz.gpg
```

Encrypted with **GPG symmetric password**.

---

# 📊 Log Files & Monitoring

**Automatic Log Creation:**
- Log files created with proper permissions during setup
- No manual intervention required

**Monitor Backups:**
```bash
# Real-time monitoring
tail -f /var/log/mongo-backup-27019-daily.log

# Check recent activity
tail -20 /var/log/mongo-backup-27019-daily.log
```

---

# 🧪 Manual Backup

```bash
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh daily
/opt/mongo-backups/<PORT>/run-mongo-s3-backup.sh monthly
```

---

# 🗄 Restore Script (Enhanced Version Handling)

**New Features:**
- Automatically installs MongoDB Shell if missing
- Handles system version conflicts during restore
- Cleans problematic system collections before restore
- Compatible with different MongoDB versions

Run:
```bash
bash stacks/mongo-backup/scripts/restore-mongo-from-s3.sh
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
✔ Automatic dependency installation

---

# 🔄 Version Conflict Handling

**Backup Strategy:**
- Backups **ALL databases** including system collections
- Comprehensive version conflict handling during restore

**Restore Strategy:**
- Automatically cleans system collections that cause version conflicts
- Safe for restoring across different MongoDB versions
- Preserves application data while handling system database conflicts
- Uses MongoDB Shell for system collection cleanup

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

```javascript
rs.stepDown()
```

Node becomes **SECONDARY** → Safe to restore.

---

## **3️⃣ Run restore script**

```bash
bash stacks/mongo-backup/scripts/restore-mongo-from-s3.sh
```

The script:

* Lists S3 backups
* Lets you choose backup index
* Downloads file
* Decrypts
* **Cleans system version data**
* Restores using:

```bash
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

# 📋 Dependencies

**Automatically Installed:**
- AWS CLI
- GPG
- MongoDB Database Tools (mongodump/mongorestore)
- **MongoDB Shell (mongosh)** - for version conflict handling

All dependencies are automatically checked and installed during setup and restore.

---

# 🛡 Recommended Backup Topology

Add hidden backup replica:

```javascript
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

# 🐛 Troubleshooting

**Cron Not Logging?**
```bash
# Create log files manually if needed
sudo touch /var/log/mongo-backup-27019-daily.log
sudo chown $(whoami):$(whoami) /var/log/mongo-backup-27019-daily.log
```

**Check Cron Status:**
```bash
sudo systemctl status cron
crontab -l
tail -f /var/log/mongo-backup-27019-daily.log
```

**View Cron Execution:**
```bash
sudo grep "CRON" /var/log/syslog | tail -5
```

**Test Backup Manually:**
```bash
/opt/mongo-backups/27019/run-mongo-s3-backup.sh daily
```

---

# ✅ Final Notes

* Backups run per-port with isolated configurations
* Restore script is standalone with automatic dependency handling
* Automatic log file creation with proper permissions
* Version conflict handling for safe cross-version restores
* Restore must run on primary after stepDown
* Replica healing is automatic
* Fully isolated multi-project design

**Production Ready Features:**
- ✅ Original cron schedule (2:30 AM daily, 3:00 AM monthly)
- ✅ Automatic log file management
- ✅ Safe cron replacement for same ports
- ✅ Comprehensive version conflict handling
- ✅ Automatic dependency installation

---