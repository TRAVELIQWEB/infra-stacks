# System Disk Protection

This infra implements a **three-layer disk safety strategy** to prevent
server lockups caused by 100% disk usage (Mongo, Docker, OS failures).

The goal is:
- Prevent disk-full situations
- Alert early
- Provide a guaranteed emergency recovery path

---

## 1️⃣ Disk Rescue File (Emergency Space)

**Purpose:**  
Reserve a fixed percentage of disk space that can be released instantly
when the server becomes unstable due to full disk.

**Script:**  
`helpers/system/disk-rescue.sh`

**What it does:**
- Detects total, used, and free disk space
- Asks what **percentage of disk** to reserve (recommended: 1–2%)
- Creates a locked rescue file

**Details:**
- Location: `/root/.disk-rescue`
- Size: Calculated from total disk (% based)
- Permissions: Read-only (400)
- Idempotent (safe to re-run)

⚠️ **Do NOT delete this file during normal operation.**

---

## 2️⃣ Disk Guard Monitor (Early Warning)

**Purpose:**  
Continuously monitor disk usage and alert before the disk becomes full.

**Script:**  
`helpers/system/disk-guard.sh`

**What it does:**
- Monitors a disk path (default `/`)
- Sends alerts when usage crosses threshold
- Installs itself into cron (idempotent)
- Uses centralized mail helper

**Key Features:**
- Threshold configurable (default: 85%)
- Cron interval asked in **minutes only** (5–50)
- Includes hostname in alert emails
- Safe for cron execution

**Runtime:**
- Runs automatically via cron

---

## 3️⃣ Disk Rescue Release (Emergency Recovery)

**Purpose:**  
Safely free reserved disk space when the server is already in a critical state.

**Script:**  
`helpers/system/disk-rescue-release.sh`

**What it does:**
- Shows disk usage BEFORE release
- Requires explicit confirmation (`YES`)
- Deletes rescue file
- Shows disk usage AFTER release

**Use ONLY when:**
- Disk reaches 100%
- Mongo / Docker fails to start
- SSH or system becomes unstable

After recovery, **recreate the rescue file immediately**.

---

## 4️⃣ Mail Alert System (Shared Infrastructure)

**Purpose:**  
Centralized SMTP-based alerting for all infra monitors.

### Mail Setup (Run Once)

**Script:**  
`helpers/system/mail-setup.sh`

**What it does:**
- Asks SMTP credentials interactively
- Auto-installs required packages (`msmtp`)
- Stores configuration securely
- Saves default alert recipient

### Mail Helper

**Helper:**  
`helpers/mail.sh`

**Used by:**
- Disk Guard
- Future monitors (CPU, memory, inode, Docker size, Mongo)

All alert emails automatically include:
- Hostname
- Timestamp
- Alert context

---

## 🚀 Initial Server Setup (Run Once)

Run these scripts **during first server bootstrap**:

```bash
helpers/system/mail-setup.sh
helpers/system/disk-rescue.sh
helpers/system/disk-guard.sh
