#!/usr/bin/env bash
set -euo pipefail

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "        MongoDB → S3 Continuous Oplog Backup"
echo -e "======================================================${RESET}"

###############################################
# 0) Dependencies
###############################################
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}Missing dependency: $1${RESET}"
    exit 1
  }
}

need_cmd mongodump
need_cmd mongosh
need_cmd jq
need_cmd aws
need_cmd gpg

###############################################
# 1) Ask Mongo details (ONLY first time)
###############################################
read -rp "Mongo port (e.g. 27017): " MONGO_PORT
read -rp "Mongo username: " MONGO_USER
read -rp "Mongo password: " MONGO_PASS
read -rp "Auth DB (default: admin): " MONGO_AUTHDB
[ -z "$MONGO_AUTHDB" ] && MONGO_AUTHDB="admin"

MONGO_HOST="127.0.0.1"

###############################################
# 2) S3 settings
###############################################
read -rp "S3 endpoint (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

read -rp "S3 bucket name: " S3_BUCKET

read -rp "S3 prefix (default: mongo-backups): " S3_PREFIX
[ -z "$S3_PREFIX" ] && S3_PREFIX="mongo-backups"

read -rp "S3 region (default: ap-south-1): " S3_REGION
[ -z "$S3_REGION" ] && S3_REGION="ap-south-1"

read -rp "S3 Access Key: " AWS_ACCESS_KEY_ID
read -rp "S3 Secret Key: " AWS_SECRET_ACCESS_KEY

###############################################
# 3) Encryption
###############################################
ENC_PASS=""
while [[ -z "$ENC_PASS" ]]; do
  read -rp "Encryption passphrase (required): " ENC_PASS
done

###############################################
# 4) Directories (NO repo storage)
###############################################
BASE_DIR="/opt/mongo-backups/${MONGO_PORT}/oplog"
STATE_DIR="${BASE_DIR}/state"
TMP_DIR="${BASE_DIR}/tmp"
CONFIG_FILE="${BASE_DIR}/oplog-config.env"
STATE_FILE="${STATE_DIR}/last_ts.json"

sudo mkdir -p "$STATE_DIR" "$TMP_DIR"
sudo chown -R "$(whoami)":"$(whoami)" "/opt/mongo-backups/${MONGO_PORT}"

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

  echo -e "${GREEN}Oplog config saved to ${CONFIG_FILE}${RESET}"
else
  echo -e "${YELLOW}Config already exists, reusing it${RESET}"
fi

###############################################
# 6) Load config
###############################################
# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

###############################################
# 7) Helpers
###############################################
mongo_uri() {
  echo "mongodb://${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}/?authSource=${MONGO_AUTHDB}"
}

###############################################
# 8) Init oplog state (first run)
###############################################
if [ ! -f "$STATE_FILE" ]; then
  echo -e "${YELLOW}Initializing oplog state...${RESET}"

  LATEST=$(mongosh --quiet "$(mongo_uri)" --eval '
    const d=db.getSiblingDB("local").oplog.rs.find().sort({$natural:-1}).limit(1).next();
    print(JSON.stringify({t:d.ts.getHighBits(),i:d.ts.getLowBits()}));
  ')

  echo "$LATEST" > "$STATE_FILE"
  echo -e "${GREEN}Oplog state initialized. Next run will archive.${RESET}"
  exit 0
fi

LAST_T=$(jq -r '.t' "$STATE_FILE")
LAST_I=$(jq -r '.i' "$STATE_FILE")

###############################################
# 9) Dump oplog delta
###############################################
TS=$(date -u +"%Y%m%d-%H%M%S")
DUMP_FILE="${TMP_DIR}/oplog-${TS}.archive.gz"
ENC_FILE="${DUMP_FILE}.gpg"

QUERY=$(jq -cn --argjson t "$LAST_T" --argjson i "$LAST_I" \
  '{ts:{ "$gt": { "$timestamp": { "t": $t, "i": $i } } }}')

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

###############################################
# 10) Encrypt + upload
###############################################
gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$DUMP_FILE"
rm -f "$DUMP_FILE"

S3_KEY="${S3_PREFIX}/${MONGO_PORT}/oplog/oplog-${TS}.archive.gz.gpg"

aws --endpoint-url "$S3_ENDPOINT" s3 cp "$ENC_FILE" "s3://${S3_BUCKET}/${S3_KEY}"
rm -f "$ENC_FILE"

###############################################
# 11) Update state
###############################################
NEW_TS=$(mongosh --quiet "$(mongo_uri)" --eval '
  const d=db.getSiblingDB("local").oplog.rs.find().sort({$natural:-1}).limit(1).next();
  print(JSON.stringify({t:d.ts.getHighBits(),i:d.ts.getLowBits()}));
')

echo "$NEW_TS" > "$STATE_FILE"

echo -e "${GREEN}Oplog archived successfully${RESET}"
