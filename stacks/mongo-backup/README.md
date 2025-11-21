# 🍃 Mongo Backup & Restore System  
### Automated Daily + Monthly Encrypted Backups → Zata (S3 Compatible)

This module provides:

- Multi-port MongoDB backups  
- Runs on hidden replica node (backup VPS)  
- `mongodump --archive --gzip`  
- Encrypted `.gpg` files  
- Upload to Zata S3  
- Daily & Monthly retention cleanup  
- Full restore script (interactive)  

---

# 🚀 Features

| Feature | Supported |
|--------|-----------|
| Multi Mongo Port Backups | ✔ |
| Zata S3 / S3 Compatible | ✔ |
| Encryption (GPG symmetric) | ✔ |
| Daily Backups | ✔ |
| Monthly Backups | ✔ |
| Retention Cleanup | ✔ |
| Auto Cron Setup | ✔ |
| Interactive Restore Script | ✔ |

---

# 📁 File Structure

```
/opt/mongo-backups/
│
├── backup-config.env             # Full configuration
├── run-mongo-s3-backup.sh        # Backup runner (daily/monthly)
├── restore-mongo-from-s3.sh      # Restore script
└── tmp/                          # Temporary files
```

---

# 🛠 Setup

Run:

```
bash stacks/mongo-backup/scripts/setup-mongo-s3-backup.sh
```

You will be asked for:

- Number of Mongo instances  
- Port / username / password  
- Zata endpoint  
- Bucket name  
- Folder prefix  
- GPG encryption password  
- Retention days / months  

This will generate:

```
/opt/mongo-backups/backup-config.env
/opt/mongo-backups/run-mongo-s3-backup.sh
```

---

# 📅 Cron Jobs Installed Automatically

Daily @ 02:30 AM:

```
/opt/mongo-backups/run-mongo-s3-backup.sh daily
```

Monthly @ 03:00 AM on 1st:

```
/opt/mongo-backups/run-mongo-s3-backup.sh monthly
```

Logs stored at:

```
/var/log/mongo-backup-daily.log
/var/log/mongo-backup-monthly.log
```

---

# 🧪 Manual Run

Daily backup:

```
/opt/mongo-backups/run-mongo-s3-backup.sh daily
```

Monthly backup:

```
/opt/mongo-backups/run-mongo-s3-backup.sh monthly
```

---

# 🔐 Encryption Details

All backups are encrypted using:

```
gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c dump.gz
```

Result:

```
filename.archive.gz.gpg
```

Only decryptable with your passphrase.

---

# 🗄 Restore Script

Run:

```
bash /opt/mongo-backups/restore-mongo-from-s3.sh
```

Restore Flow:

1. Select Mongo port  
2. Select daily/monthly  
3. Select backup index from S3  
4. Backup is downloaded  
5. GPG decrypted  
6. Extracted  
7. Restored via:

```
mongorestore --archive dump.archive --gzip --drop
```

---

# 🧹 Retention Cleanup Logic

### Daily  
Keep last **10** backups per port.

### Monthly  
Keep last **6** backups per port.

Automatically deletes the oldest backups beyond retention.

---

# 🛡 Hidden Backup Replica (VPS4)

Backups should always run on your hidden replica:

```
priority: 0
votes: 0
hidden: true
```

Configured using:

```
rs.add({
  host: "10.50.x.x:27019",
  priority: 0,
  hidden: true,
  votes: 0
})
```

This ensures:

- No read/write load on primary  
- Always up-to-date replica  
- Safe for backups  

---

# 🧾 Restore Example

```
Mongo Ports Available:
 - 27019

Enter port: 27019
Enter restore type: daily
Choose backup index: 3
Target host: 127.0.0.1
Target port: 27019
User: superuser
Pass: *****
Auth DB: admin
```

Backup restored successfully.

---

# 🎉 Done  
Your Mongo backup system is now fully documented and production-ready.
