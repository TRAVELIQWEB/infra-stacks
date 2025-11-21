#!/usr/bin/env bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "        MongoDB → Zata (S3) Backup Setup Script"
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
# 1) Ask for Mongo instances
###############################################
read -rp "How many MongoDB instances do you want to back up? " MONGO_COUNT

if ! [[ "$MONGO_COUNT" =~ ^[0-9]+$ ]] || [ "$MONGO_COUNT" -le 0 ]; then
  echo -e "${RED}Invalid number. Exiting.${RESET}"
  exit 1
fi

MONGO_PORTS=""

for (( i=1; i<=MONGO_COUNT; i++ )); do
  echo -e "\n${YELLOW}--- Mongo Instance #$i ---${RESET}"
  read -rp "Mongo port (e.g., 27019): " PORT
  read -rp "Mongo username for this port: " USER
  read -rp "Mongo password for this port: " PASS
  read -rp "Auth DB for this port (default: admin): " AUTHDB
  [ -z "$AUTHDB" ] && AUTHDB="admin"

  # host is local inside VPS4 where mongodump runs
  HOST="127.0.0.1"

  MONGO_PORTS="$MONGO_PORTS $PORT"

  # Store per-port vars in config later
  INSTANCE_VARS+="
MONGO_HOST_${PORT}=\"${HOST}\"
MONGO_USER_${PORT}=\"${USER}\"
MONGO_PASS_${PORT}=\"${PASS}\"
MONGO_AUTHDB_${PORT}=\"${AUTHDB}\"
"
done

MONGO_PORTS=$(echo "$MONGO_PORTS" | xargs)  # trim spaces

###############################################
# 2) Ask for Zata S3 settings
###############################################
echo -e "\n${BLUE}--- Zata (S3-compatible) Settings ---${RESET}"

# Endpoint: let user override, but give a sane default
read -rp "Zata S3 Endpoint URL (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

read -rp "S3 Bucket Name: " S3_BUCKET
read -rp "S3 Folder Prefix (e.g., wallet-mongo): " S3_PREFIX
read -rp "S3 Region (e.g., ap-south-1): " S3_REGION

echo -e "\n${YELLOW}--- Zata S3 Credentials (Access Key) ---${RESET}"
read -rp "S3 Access Key ID: " S3_ACCESS_KEY_ID
read -rp "S3 Secret Access Key: " S3_SECRET_ACCESS_KEY

###############################################
# 3) Encryption & retention settings
###############################################
echo -e "\n${BLUE}--- Encryption & Retention ---${RESET}"

read -rp "Encryption password (GPG symmetric key): " ENC_PASS

read -rp "Daily backup retention (days, default 10): " DAILY_RET
[ -z "$DAILY_RET" ] && DAILY_RET=10

read -rp "Monthly backup retention (count, default 6): " MONTHLY_RET
[ -z "$MONTHLY_RET" ] && MONTHLY_RET=6

###############################################
# 4) Create backup directory & config
###############################################
BACKUP_DIR="/opt/mongo-backups"
CONFIG_FILE="${BACKUP_DIR}/backup-config.env"
RUN_SCRIPT="${BACKUP_DIR}/run-mongo-s3-backup.sh"

echo -e "\n${BLUE}Creating backup directory at ${BACKUP_DIR}...${RESET}"
sudo mkdir -p "$BACKUP_DIR"
sudo chown "$(whoami)":"$(whoami)" "$BACKUP_DIR"

echo -e "${BLUE}Writing config file: ${CONFIG_FILE}${RESET}"

cat > "$CONFIG_FILE" <<EOF
# MongoDB → Zata S3 Backup Configuration

BACKUP_DIR="${BACKUP_DIR}"

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

# Mongo instances (ports)
MONGO_PORTS="${MONGO_PORTS}"
${INSTANCE_VARS}
EOF

echo -e "${GREEN}Config saved to ${CONFIG_FILE}${RESET}"

###############################################
# 5) Create the runtime backup script
###############################################
echo -e "${BLUE}Writing backup runner script: ${RUN_SCRIPT}${RESET}"

cat > "$RUN_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e

# Load config
CONFIG_FILE="/opt/mongo-backups/backup-config.env"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Ensure env vars for AWS CLI
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

MODE="${1:-daily}"   # daily | monthly

if [ "$MODE" != "daily" ] && [ "$MODE" != "monthly" ]; then
  echo "Usage: $0 [daily|monthly]"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SUBFOLDER="$MODE"

mkdir -p "$BACKUP_DIR/tmp"

echo "=== Mongo Backup Started: MODE=$MODE, TIME=$TIMESTAMP ==="

for PORT in $MONGO_PORTS; do
  HOST_VAR="MONGO_HOST_${PORT}"
  USER_VAR="MONGO_USER_${PORT}"
  PASS_VAR="MONGO_PASS_${PORT}"
  AUTHDB_VAR="MONGO_AUTHDB_${PORT}"

  HOST="${!HOST_VAR}"
  USER="${!USER_VAR}"
  PASS="${!PASS_VAR}"
  AUTHDB="${!AUTHDB_VAR}"

  if [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$PASS" ] || [ -z "$AUTHDB" ]; then
    echo "Skipping port ${PORT}: missing config variables."
    continue
  fi

  DUMP_FILE="${BACKUP_DIR}/tmp/mongo-${PORT}-${MODE}-${TIMESTAMP}.archive.gz"
  ENC_FILE="${DUMP_FILE}.gpg"

  echo "--- Dumping MongoDB port ${PORT} ---"
  mongodump \
    --host "$HOST" \
    --port "$PORT" \
    -u "$USER" \
    -p "$PASS" \
    --authenticationDatabase "$AUTHDB" \
    --gzip \
    --archive="$DUMP_FILE"

  echo "--- Encrypting dump for port ${PORT} ---"
  gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$DUMP_FILE"

  rm -f "$DUMP_FILE"

  S3_KEY="${S3_PREFIX}/${PORT}/${SUBFOLDER}/mongo-${PORT}-${MODE}-${TIMESTAMP}.archive.gz.gpg"

  echo "--- Uploading to S3: s3://${S3_BUCKET}/${S3_KEY} ---"
  aws --endpoint-url "$S3_ENDPOINT" s3 cp "$ENC_FILE" "s3://${S3_BUCKET}/${S3_KEY}"

  rm -f "$ENC_FILE"
done

###############################################
# Retention Cleanup
###############################################
if [ "$MODE" = "daily" ]; then
  RETENTION=$DAILY_RETENTION
else
  RETENTION=$MONTHLY_RETENTION
fi

echo "=== Applying retention policy: MODE=$MODE, RETENTION=$RETENTION ==="

for PORT in $MONGO_PORTS; do
  PREFIX_PATH="${S3_PREFIX}/${PORT}/${SUBFOLDER}/"

  # List objects, extract keys, oldest first
  OBJECTS=$(aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX_PATH}" 2>/dev/null | awk '{print $4}' | sort)

  if [ -z "$OBJECTS" ]; then
    echo "No backups found for port ${PORT} (${MODE})."
    continue
  fi

  COUNT=$(echo "$OBJECTS" | wc -l)

  if [ "$COUNT" -le "$RETENTION" ]; then
    echo "Port ${PORT} (${MODE}): ${COUNT}/${RETENTION} backups – nothing to delete."
    continue
  fi

  DELETE_COUNT=$((COUNT - RETENTION))
  echo "Port ${PORT} (${MODE}): ${COUNT} backups, deleting ${DELETE_COUNT} oldest."

  echo "$OBJECTS" | head -n "$DELETE_COUNT" | while read -r KEY; do
    [ -z "$KEY" ] && continue
    echo "Deleting s3://${S3_BUCKET}/${PREFIX_PATH}${KEY}"
    aws --endpoint-url "$S3_ENDPOINT" s3 rm "s3://${S3_BUCKET}/${PREFIX_PATH}${KEY}"
  done
done

echo "=== Mongo Backup Completed: MODE=$MODE, TIME=$TIMESTAMP ==="
EOF

chmod +x "$RUN_SCRIPT"

###############################################
# 6) Setup cron jobs
###############################################
echo -e "${BLUE}Setting up cron jobs...${RESET}"

CRON_CMD="$RUN_SCRIPT"

# Remove old entries of same script
( crontab -l 2>/dev/null | grep -v "$CRON_CMD" || true ) > /tmp/current_cron.$$ || true

# Daily backup at 02:30
echo "30 2 * * * $CRON_CMD daily >> /var/log/mongo-backup-daily.log 2>&1" >> /tmp/current_cron.$$

# Monthly backup on 1st at 03:00
echo "0 3 1 * * $CRON_CMD monthly >> /var/log/mongo-backup-monthly.log 2>&1" >> /tmp/current_cron.$$

crontab /tmp/current_cron.$$
rm -f /tmp/current_cron.$$

echo -e "${GREEN}Cron jobs installed:${RESET}"
echo "  - Daily :  02:30 → $CRON_CMD daily"
echo "  - Monthly: 03:00 (1st of month) → $CRON_CMD monthly"

echo -e "\n${GREEN}Setup complete!${RESET}"
echo "You can test manually with:"
echo "  $RUN_SCRIPT daily"
echo "  $RUN_SCRIPT monthly"
