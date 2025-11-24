#!/usr/bin/env bash
set -e

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "        MongoDB → Zata (S3) PER-PORT Backup Setup"
echo -e "======================================================${RESET}"

###############################################
# 0) Check & install dependencies
###############################################
need_install=()

command -v aws >/dev/null 2>&1 || need_install+=("awscli")
command -v zip >/dev/null 2>&1 || need_install+=("zip")
command -v gpg >/dev/null 2>&1 || need_install+=("gpg")

if [ ${#need_install[@]} -gt 0 ]; then
  echo -e "${YELLOW}Installing missing packages: ${need_install[*]}${RESET}"
  sudo apt update -y
  sudo apt install -y "${need_install[@]}"
else
  echo -e "${GREEN}awscli, zip, gpg already installed.${RESET}"
fi

###############################################
# Install MongoDB Tools (mongodump/mongorestore)
###############################################
if ! command -v mongodump >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing MongoDB Database Tools (manual .deb)...${RESET}"

  TMP_DEB="/tmp/mongodb-tools.deb"

  
  wget -qO "$TMP_DEB" \
    "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.13.0.deb"

  sudo apt install -y "$TMP_DEB"
  rm -f "$TMP_DEB"

  if command -v mongodump >/dev/null 2>&1; then
    echo -e "${GREEN}MongoDB Tools installed successfully.${RESET}"
  else
    echo -e "${RED}MongoDB Tools installation failed!${RESET}"
    exit 1
  fi
else
  echo -e "${GREEN}MongoDB Tools already installed.${RESET}"
fi

###############################################
# 1) Ask for ONE Mongo instance (per run)
###############################################
echo -e "\n${YELLOW}--- Mongo Instance Details (for THIS setup run) ---${RESET}"

read -rp "Mongo port (e.g., 27017, 27019): " MONGO_PORT
read -rp "Mongo username: " MONGO_USER
read -rp "Mongo password: " MONGO_PASS
read -rp "Auth DB (default: admin): " MONGO_AUTHDB
[ -z "$MONGO_AUTHDB" ] && MONGO_AUTHDB="admin"

MONGO_HOST="127.0.0.1"

###############################################
# 2) Zata S3 settings (per port)
###############################################
echo -e "\n${BLUE}--- Zata (S3-compatible) Settings ---${RESET}"

read -rp "Zata S3 Endpoint URL (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

# Ensure it starts with http/https
if [[ "$S3_ENDPOINT" != http* ]]; then
  S3_ENDPOINT="https://${S3_ENDPOINT}"
fi

read -rp "S3 Bucket Name: " S3_BUCKET

read -rp "S3 Folder Prefix (project name, e.g., fwms, wallet) [default: mongo-backups]: " S3_PREFIX
[ -z "$S3_PREFIX" ] && S3_PREFIX="mongo-backups"

read -rp "S3 Region (default: ap-south-1): " S3_REGION
[ -z "$S3_REGION" ] && S3_REGION="ap-south-1"

echo -e "\n${YELLOW}--- Zata S3 Credentials (Access Key) ---${RESET}"
read -rp "S3 Access Key ID: " S3_ACCESS_KEY_ID
read -rp "S3 Secret Access Key: " S3_SECRET_ACCESS_KEY

###############################################
# 3) Encryption & retention settings
###############################################
echo -e "\n${BLUE}--- Encryption & Retention ---${RESET}"

ENC_PASS=""
while [[ -z "$ENC_PASS" ]]; do
  read -rp "Encryption password (GPG symmetric key) (cannot be empty): " ENC_PASS
done

read -rp "Daily backup retention (days, default 10): " DAILY_RET
[ -z "$DAILY_RET" ] && DAILY_RET=10

read -rp "Monthly backup retention (count, default 6): " MONTHLY_RET
[ -z "$MONTHLY_RET" ] && MONTHLY_RET=6

###############################################
# 4) Per-port backup directory & config
###############################################
BASE_DIR="/opt/mongo-backups"
PORT_DIR="${BASE_DIR}/${MONGO_PORT}"
CONFIG_FILE="${PORT_DIR}/backup-config.env"
RUN_SCRIPT="${PORT_DIR}/run-mongo-s3-backup.sh"
RESTORE_SCRIPT="${PORT_DIR}/restore-mongo-from-s3.sh"
TMP_DIR="${PORT_DIR}/tmp"

echo -e "\n${BLUE}Creating per-port backup directory at ${PORT_DIR}...${RESET}"
sudo mkdir -p "$TMP_DIR"
sudo chown -R "$(whoami)":"$(whoami)" "$BASE_DIR"

echo -e "${BLUE}Writing config file: ${CONFIG_FILE}${RESET}"

cat > "$CONFIG_FILE" <<EOF
# MongoDB → Zata S3 Backup Configuration (per-port)

BACKUP_DIR="${PORT_DIR}"
TMP_DIR="${TMP_DIR}"

# Mongo connection
MONGO_PORT="${MONGO_PORT}"
MONGO_HOST="${MONGO_HOST}"
MONGO_USER="${MONGO_USER}"
MONGO_PASS="${MONGO_PASS}"
MONGO_AUTHDB="${MONGO_AUTHDB}"

# Zata / S3 settings
S3_ENDPOINT="${S3_ENDPOINT}"
S3_BUCKET="${S3_BUCKET}"
S3_PREFIX="${S3_PREFIX}"
S3_REGION="${S3_REGION}"

# AWS-style credentials for Zata
AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}"

# Encryption
ENCRYPTION_PASSPHRASE="${ENC_PASS}"

# Retention
DAILY_RETENTION=${DAILY_RET}
MONTHLY_RETENTION=${MONTHLY_RET}
EOF

echo -e "${GREEN}Config saved to ${CONFIG_FILE}${RESET}"

###############################################
# 5) Create per-port backup runner script
###############################################
echo -e "${BLUE}Writing backup runner script: ${RUN_SCRIPT}${RESET}"

cat > "$RUN_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup-config.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

MODE="${1:-daily}"  # daily | monthly

if [ "$MODE" != "daily" ] && [ "$MODE" != "monthly" ]; then
  echo "Usage: $0 [daily|monthly]"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SUBFOLDER="$MODE"

mkdir -p "$TMP_DIR"

echo "=== Mongo Backup Started: PORT=$MONGO_PORT MODE=$MODE TIME=$TIMESTAMP ==="

DUMP_FILE="${TMP_DIR}/mongo-${MONGO_PORT}-${MODE}-${TIMESTAMP}.archive.gz"
ENC_FILE="${DUMP_FILE}.gpg"

echo "--- Dumping MongoDB port ${MONGO_PORT} ---"
/usr/lib/mongodb-database-tools/bin/mongodump \
  --host "$MONGO_HOST" \
  --port "$MONGO_PORT" \
  -u "$MONGO_USER" \
  -p "$MONGO_PASS" \
  --authenticationDatabase "$MONGO_AUTHDB" \
  --gzip \
  --archive="$DUMP_FILE" \
  --nsExclude admin.system.version \
  --nsExclude admin.system.users \
  --nsExclude admin.system.roles \
  --nsExclude config.system.sessions \
  --nsExclude local.*



echo "--- Encrypting dump ---"
gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$DUMP_FILE"
rm -f "$DUMP_FILE"

S3_KEY="${S3_PREFIX}/${MONGO_PORT}/${SUBFOLDER}/mongo-${MONGO_PORT}-${MODE}-${TIMESTAMP}.archive.gz.gpg"

echo "--- Uploading to S3: s3://${S3_BUCKET}/${S3_KEY} ---"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$ENC_FILE" "s3://${S3_BUCKET}/${S3_KEY}"
rm -f "$ENC_FILE"

###############################################
# Retention Cleanup
###############################################
RETENTION=$DAILY_RETENTION
[ "$MODE" = "monthly" ] && RETENTION=$MONTHLY_RETENTION

echo "=== Retention Cleanup (keep last $RETENTION ${MODE} backups) ==="

PREFIX_PATH="${S3_PREFIX}/${MONGO_PORT}/${SUBFOLDER}/"

OBJECTS=$(aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX_PATH}" 2>/dev/null | awk '{print $4}' | sort)

if [ -z "$OBJECTS" ]; then
  echo "No backups found for ${MONGO_PORT}/${SUBFOLDER}"
else
  COUNT=$(echo "$OBJECTS" | wc -l)
  if [ "$COUNT" -le "$RETENTION" ]; then
    echo "Backups: ${COUNT}/${RETENTION} → nothing to delete."
  else
    DELETE_COUNT=$((COUNT - RETENTION))
    echo "Backups: ${COUNT}/${RETENTION} → deleting ${DELETE_COUNT} oldest."
    echo "$OBJECTS" | head -n "$DELETE_COUNT" | while read -r KEY; do
      [ -z "$KEY" ] && continue
      echo "Deleting s3://${S3_BUCKET}/${PREFIX_PATH}${KEY}"
      aws --endpoint-url "$S3_ENDPOINT" s3 rm "s3://${S3_BUCKET}/${PREFIX_PATH}${KEY}"
    done
  fi
fi

echo "=== Mongo Backup Completed (PORT=$MONGO_PORT MODE=$MODE) ==="
EOF

chmod +x "$RUN_SCRIPT"

###############################################
# 6) Create per-port restore script
###############################################
echo -e "${BLUE}Writing restore script: ${RESTORE_SCRIPT}${RESET}"

cat > "$RESTORE_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup-config.env"

echo -e "${BLUE}====================================================="
echo -e "                 MongoDB Restore Script"
echo -e "=====================================================${RESET}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Backup config file not found: $CONFIG_FILE${RESET}"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

###########################################
# Pickup Restore Mode (daily or monthly)
###########################################
read -rp "Restore type? (daily/monthly): " MODE
if [[ "$MODE" != "daily" && "$MODE" != "monthly" ]]; then
  echo -e "${RED}Invalid mode. Choose daily or monthly.${RESET}"
  exit 1
fi

PREFIX="${S3_PREFIX}/${MONGO_PORT}/${MODE}/"

echo -e "${BLUE}Fetching backup list from S3 (s3://${S3_BUCKET}/${PREFIX})...${RESET}"

TMP_LIST="${TMP_DIR}/s3list-${MONGO_PORT}-${MODE}.txt"
mkdir -p "$TMP_DIR"

aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > "$TMP_LIST" 2>/dev/null || true

if ! [[ -s "$TMP_LIST" ]]; then
  echo -e "${RED}No backups found in S3 for this port/mode.${RESET}"
  exit 1
fi

echo -e "${GREEN}Available backups:${RESET}"
nl -w2 -s". " "$TMP_LIST"

###########################################
# Ask user which backup to restore
###########################################
read -rp "Enter file index to restore: " FILE_INDEX

FILE_NAME=$(sed -n "${FILE_INDEX}p" "$TMP_LIST" | awk '{print $4}')

if [[ -z "$FILE_NAME" ]]; then
  echo -e "${RED}Invalid selection.${RESET}"
  exit 1
fi

echo -e "${BLUE}Selected backup: ${FILE_NAME}${RESET}"

###########################################
# Download backup
###########################################
DOWNLOAD_PATH="${TMP_DIR}/${FILE_NAME}"

echo -e "${YELLOW}Downloading backup from S3...${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://${S3_BUCKET}/${PREFIX}${FILE_NAME}" \
  "$DOWNLOAD_PATH"

###########################################
# Decrypt backup (keep .gz)
###########################################
DECRYPTED="${DOWNLOAD_PATH%.gpg}"   # will still end with .gz

echo -e "${YELLOW}Decrypting backup...${RESET}"

gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "$DOWNLOAD_PATH" > "$DECRYPTED"

###########################################
# Ask for Target Mongo host/port/creds
###########################################
read -rp "Target Mongo host (default: 127.0.0.1): " TARGET_HOST
[ -z "$TARGET_HOST" ] && TARGET_HOST="127.0.0.1"

read -rp "Target Mongo port (default: $MONGO_PORT): " TARGET_PORT
[ -z "$TARGET_PORT" ] && TARGET_PORT="$MONGO_PORT"

read -rp "Target Mongo username: " TARGET_USER
read -rp "Target Mongo password: " TARGET_PASS
read -rp "Auth DB (default: admin): " TARGET_AUTHDB
[ -z "$TARGET_AUTHDB" ] && TARGET_AUTHDB="admin"

###########################################
# Restore into Target Mongo
###########################################
echo -e "${BLUE}Restoring into MongoDB ${TARGET_HOST}:${TARGET_PORT} ...${RESET}"

mongorestore \
  --host "$TARGET_HOST" \
  --port "$TARGET_PORT" \
  -u "$TARGET_USER" \
  -p "$TARGET_PASS" \
  --authenticationDatabase "$TARGET_AUTHDB" \
  --archive="$DECRYPTED" \
  --gzip \
  --drop

echo -e "${GREEN}Restore completed successfully!${RESET}"

###########################################
# Cleanup temp files
###########################################
rm -f "$DOWNLOAD_PATH" "$DECRYPTED" "$TMP_LIST"

echo -e "${BLUE}Temporary files cleaned.${RESET}"
EOF

chmod +x "$RESTORE_SCRIPT"

###############################################
# 7) Setup cron jobs (PER PORT — SAFE VERSION)
###############################################
echo -e "${BLUE}Setting up cron jobs for port ${MONGO_PORT}...${RESET}"

CRON_CMD="$RUN_SCRIPT"

# Ensure script exists before adding cron
if [[ ! -f "$CRON_CMD" ]]; then
  echo -e "${RED}ERROR: Backup script missing — cannot add cron job.${RESET}"
  exit 1
fi

# Create a clean temporary cron file
TEMP_CRON="/tmp/cron-${MONGO_PORT}-$$"

# Load existing crontab except old entries for this script
crontab -l 2>/dev/null | grep -v "$CRON_CMD" > "$TEMP_CRON" || true

# Append NEW cron entries (daily & monthly)
echo "30 2 * * * $CRON_CMD daily >> /var/log/mongo-backup-${MONGO_PORT}-daily.log 2>&1" >> "$TEMP_CRON"
echo "0 3 1 * * $CRON_CMD monthly >> /var/log/mongo-backup-${MONGO_PORT}-monthly.log 2>&1" >> "$TEMP_CRON"

# Validate before applying
if ! crontab "$TEMP_CRON"; then
  echo -e "${RED}Cron installation failed! Showing generated file:${RESET}"
  echo "-----------------------------------------------------"
  sed -n '1,50p' "$TEMP_CRON"
  echo "-----------------------------------------------------"
  rm -f "$TEMP_CRON"
  exit 1
fi

# Cleanup
rm -f "$TEMP_CRON"

echo -e "${GREEN}Cron jobs installed successfully for port ${MONGO_PORT}.${RESET}"
echo "Daily:    02:30 → $CRON_CMD daily"
echo "Monthly:  03:00 → $CRON_CMD monthly"
echo ""
echo "To test manually:"
echo "  $CRON_CMD daily"
echo "  $CRON_CMD monthly"
echo ""
echo -e "${GREEN}Setup complete for Mongo port ${MONGO_PORT}!${RESET}"
