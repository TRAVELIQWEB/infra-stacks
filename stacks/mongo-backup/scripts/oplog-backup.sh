# FILE: stacks/mongo-backup/scripts/oplog-setup.sh
#!/usr/bin/env bash
set -euo pipefail

BLUE="\e[34m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "        MongoDB → S3 Continuous Oplog Backup (SETUP)"
echo -e "======================================================${RESET}"

###############################################
# 0) Install deps if missing
###############################################
need_install=()

command -v aws >/dev/null 2>&1 || need_install+=("awscli")
command -v gpg >/dev/null 2>&1 || need_install+=("gpg")
command -v jq  >/dev/null 2>&1 || need_install+=("jq")
command -v mongodump >/dev/null 2>&1 || need_install+=("mongodb-database-tools")

if [ ${#need_install[@]} -gt 0 ]; then
  echo -e "${YELLOW}Installing missing packages: ${need_install[*]}${RESET}"
  sudo apt update -y
  sudo apt install -y "${need_install[@]}"
else
  echo -e "${GREEN}awscli, gpg, jq, mongodump already installed.${RESET}"
fi

# Ensure mongosh exists (client only)
if ! command -v mongosh >/dev/null 2>&1; then
  echo -e "${YELLOW}mongosh not found. Installing MongoDB Shell...${RESET}"

  if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
  fi

  if [ ! -f /etc/apt/sources.list.d/mongodb-org-8.0.list ]; then
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" \
      | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
  fi

  sudo apt update -y
  sudo apt install -y mongodb-mongosh
  echo -e "${GREEN}mongosh installed successfully.${RESET}"
else
  echo -e "${GREEN}mongosh already installed. Skipping.${RESET}"
fi

###############################################
# 1) Ask Mongo details (one-time setup)
###############################################
echo -e "\n${YELLOW}--- Mongo Instance Details (for THIS setup run) ---${RESET}"
read -rp "Mongo port (e.g. 27017): " MONGO_PORT
read -rp "Mongo username: " MONGO_USER
read -rp "Mongo password: " MONGO_PASS
read -rp "Auth DB (default: admin): " MONGO_AUTHDB
[ -z "$MONGO_AUTHDB" ] && MONGO_AUTHDB="admin"

MONGO_HOST="127.0.0.1"

###############################################
# 2) S3 settings
###############################################
echo -e "\n${BLUE}--- S3 Settings ---${RESET}"
read -rp "S3 endpoint (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"
if [[ "$S3_ENDPOINT" != http* ]]; then S3_ENDPOINT="https://${S3_ENDPOINT}"; fi

read -rp "S3 bucket name: " S3_BUCKET
read -rp "S3 prefix (default: mongo-backups): " S3_PREFIX
[ -z "$S3_PREFIX" ] && S3_PREFIX="mongo-backups"
read -rp "S3 region (default: ap-south-1): " S3_REGION
[ -z "$S3_REGION" ] && S3_REGION="ap-south-1"

echo -e "\n${YELLOW}--- S3 Credentials ---${RESET}"
read -rp "S3 Access Key: " AWS_ACCESS_KEY_ID
read -rp "S3 Secret Key: " AWS_SECRET_ACCESS_KEY

###############################################
# 3) Encryption
###############################################
echo -e "\n${BLUE}--- Encryption ---${RESET}"
ENC_PASS=""
while [[ -z "$ENC_PASS" ]]; do
  read -rp "Encryption passphrase (required): " ENC_PASS
done

###############################################
# 4) Directories (NO repo storage)
###############################################
PORT_DIR="/opt/mongo-backups/${MONGO_PORT}"
OPLOG_DIR="${PORT_DIR}/oplog"
STATE_DIR="${OPLOG_DIR}/state"
TMP_DIR="${OPLOG_DIR}/tmp"
CONFIG_FILE="${OPLOG_DIR}/oplog-config.env"
STATE_FILE="${STATE_DIR}/last_ts.json"
RUNNER="${PORT_DIR}/run-oplog-backup.sh"
LOG_FILE="/var/log/mongo-oplog-${MONGO_PORT}.log"

sudo mkdir -p "$STATE_DIR" "$TMP_DIR"
sudo chown -R "$(whoami)":"$(whoami)" "$PORT_DIR"

###############################################
# 5) Write config (one-time)
###############################################
if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<EOF
MONGO_PORT="${MONGO_PORT}"
MONGO_HOST="${MONGO_HOST}"
MONGO_USER="${MONGO_USER}"
MONGO_PASS="${MONGO_PASS}"
MONGO_AUTHDB="${MONGO_AUTHDB}"

S3_ENDPOINT="${S3_ENDPOINT}"
S3_BUCKET="${S3_BUCKET}"
S3_PREFIX="${S3_PREFIX}"
S3_REGION="${S3_REGION}"

AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

ENCRYPTION_PASSPHRASE="${ENC_PASS}"
EOF
  chmod 600 "$CONFIG_FILE"
  echo -e "${GREEN}Oplog config saved: ${CONFIG_FILE}${RESET}"
else
  echo -e "${YELLOW}Config already exists, reusing: ${CONFIG_FILE}${RESET}"
fi

###############################################
# 6) Init oplog state (first run sets baseline)
###############################################
# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

mongo_uri() {
  echo "mongodb://${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}/?authSource=${MONGO_AUTHDB}"
}

if [ ! -f "$STATE_FILE" ]; then
  echo -e "${YELLOW}Initializing oplog state (baseline, no backfill)...${RESET}"
  LATEST="$(mongosh --quiet "$(mongo_uri)" --eval '
    const d=db.getSiblingDB("local").getCollection("oplog.rs")
      .find().sort({$natural:-1}).limit(1).next();
    if (!d || !d.ts) { print(""); quit(2); }
    print(JSON.stringify({t:d.ts.getHighBits(),i:d.ts.getLowBits()}));
  ' || true)"

  if [ -z "$LATEST" ]; then
    echo -e "${RED}Failed to read local.oplog.rs. Ensure replica set is enabled.${RESET}"
    exit 1
  fi

  echo "$LATEST" > "$STATE_FILE"
  chmod 600 "$STATE_FILE"
  echo -e "${GREEN}State initialized: ${STATE_FILE}${RESET}"
else
  echo -e "${GREEN}State already exists: ${STATE_FILE}${RESET}"
fi

###############################################
# 7) Create NON-INTERACTIVE runner
###############################################
cat > "$RUNNER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OPLOG_DIR="${PORT_DIR}/oplog"
CONFIG_FILE="${OPLOG_DIR}/oplog-config.env"
STATE_FILE="${OPLOG_DIR}/state/last_ts.json"
TMP_DIR="${OPLOG_DIR}/tmp"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

mongo_uri() {
  echo "mongodb://${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}/?authSource=${MONGO_AUTHDB}"
}

# Ensure state exists
if [ ! -f "$STATE_FILE" ]; then
  echo "State file missing: $STATE_FILE"
  exit 1
fi

LAST_T="$(jq -r '.t' "$STATE_FILE")"
LAST_I="$(jq -r '.i' "$STATE_FILE")"

NEW_COUNT="$(mongosh --quiet "$(mongo_uri)" --eval "
  const n = db.getSiblingDB('local').getCollection('oplog.rs')
    .countDocuments({ ts: { \\$gt: Timestamp(${LAST_T},${LAST_I}) } });
  print(n);
" || true)"

if [ -z "${NEW_COUNT:-}" ] || ! [[ "$NEW_COUNT" =~ ^[0-9]+$ ]]; then
  echo "Failed to count oplog entries. NEW_COUNT='$NEW_COUNT'"
  exit 1
fi

if [ "$NEW_COUNT" -eq 0 ]; then
  exit 0
fi

TS="$(date -u +"%Y%m%d-%H%M%S")"
DUMP_FILE="${TMP_DIR}/oplog-${MONGO_PORT}-${TS}.archive.gz"
ENC_FILE="${DUMP_FILE}.gpg"

QUERY="$(jq -cn --argjson t "$LAST_T" --argjson i "$LAST_I" \
  '{ts:{ "$gt": { "$timestamp": { "t": $t, "i": $i } } }}')"

mkdir -p "$TMP_DIR"

mongodump \
  --host "$MONGO_HOST" \
  --port "$MONGO_PORT" \
  -u "$MONGO_USER" \
  -p "$MONGO_PASS" \
  --authenticationDatabase "$MONGO_AUTHDB" \
  --db local \
  --collection oplog.rs \
  --query "$QUERY" \
  --gzip \
  --archive="$DUMP_FILE"

gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$DUMP_FILE"
rm -f "$DUMP_FILE"

S3_KEY="${S3_PREFIX}/${MONGO_PORT}/oplog/oplog-${MONGO_PORT}-${TS}.archive.gz.gpg"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$ENC_FILE" "s3://${S3_BUCKET}/${S3_KEY}"
rm -f "$ENC_FILE"

NEW_TS="$(mongosh --quiet "$(mongo_uri)" --eval '
  const d=db.getSiblingDB("local").getCollection("oplog.rs")
    .find().sort({$natural:-1}).limit(1).next();
  if (!d || !d.ts) { print(""); quit(2); }
  print(JSON.stringify({t:d.ts.getHighBits(),i:d.ts.getLowBits()}));
' || true)"

if [ -z "$NEW_TS" ]; then
  echo "Failed to read latest oplog ts for state update."
  exit 1
fi

echo "$NEW_TS" > "$STATE_FILE"
EOF

chmod +x "$RUNNER"
echo -e "${GREEN}Runner created: ${RUNNER}${RESET}"

###############################################
# 8) Install cron (every minute) + log
###############################################
sudo touch "$LOG_FILE"
sudo chown "$(whoami)":"$(whoami)" "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

CRON_LINE="* * * * * ${RUNNER} >> ${LOG_FILE} 2>&1"
( crontab -l 2>/dev/null | grep -vF "${RUNNER}" ; echo "${CRON_LINE}" ) | crontab -

echo -e "${GREEN}Cron installed: every minute${RESET}"
echo -e "${GREEN}Log file: ${LOG_FILE}${RESET}"
echo -e "${GREEN}Done.${RESET}"
