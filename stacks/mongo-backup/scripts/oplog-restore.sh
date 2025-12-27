#!/usr/bin/env bash
set -euo pipefail

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "        MongoDB ← S3 Oplog Restore (PITR)"
echo -e "======================================================${RESET}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}Missing dependency: $1${RESET}"
    exit 1
  }
}

need_cmd aws
need_cmd gpg
need_cmd mongorestore
need_cmd jq

###############################################
# 1) Ask for port (to locate /opt config)
###############################################
read -rp "Mongo port (e.g. 27017): " MONGO_PORT

OPLOG_BASE_DIR="/opt/mongo-backups/${MONGO_PORT}/oplog"
CONFIG_FILE="${OPLOG_BASE_DIR}/oplog-config.env"
TMP_DIR="${OPLOG_BASE_DIR}/tmp"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Oplog config not found: ${CONFIG_FILE}${RESET}"
  echo -e "${YELLOW}Run oplog-backup.sh once to create config.${RESET}"
  exit 1
fi

mkdir -p "$TMP_DIR"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

###############################################
# 2) Target Mongo details (restore destination)
###############################################
read -rp "Target Mongo host (default: 127.0.0.1): " TARGET_HOST
[ -z "$TARGET_HOST" ] && TARGET_HOST="127.0.0.1"

read -rp "Target Mongo port (default: ${MONGO_PORT}): " TARGET_PORT
[ -z "$TARGET_PORT" ] && TARGET_PORT="${MONGO_PORT}"

read -rp "Target Mongo username: " TARGET_USER
read -rp "Target Mongo password: " TARGET_PASS
read -rp "Target Auth DB (default: admin): " TARGET_AUTHDB
[ -z "$TARGET_AUTHDB" ] && TARGET_AUTHDB="admin"

###############################################
# 3) Restore mode: replay all files in order
###############################################
echo -e "\n${BLUE}Listing oplog chunks in S3...${RESET}"
S3_PREFIX_PATH="${S3_PREFIX}/${MONGO_PORT}/oplog/"

TMP_LIST="${TMP_DIR}/oplog-list.txt"
aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${S3_PREFIX_PATH}" \
  | awk '{print $4}' | sort > "$TMP_LIST"

if ! [[ -s "$TMP_LIST" ]]; then
  echo -e "${RED}No oplog files found in s3://${S3_BUCKET}/${S3_PREFIX_PATH}${RESET}"
  exit 1
fi

echo -e "${GREEN}Found $(wc -l < "$TMP_LIST") oplog chunks.${RESET}"
echo -e "${YELLOW}This will replay ALL oplog chunks in sorted order.${RESET}"

read -rp "Continue? (y/n): " OK
[ "$OK" != "y" ] && exit 0

###############################################
# 4) Replay each chunk
###############################################
while read -r KEY; do
  [ -z "$KEY" ] && continue

  FILE_NAME="$(basename "$KEY")"
  DL_PATH="${TMP_DIR}/${FILE_NAME}"
  DEC_PATH="${TMP_DIR}/${FILE_NAME%.gpg}"

  echo -e "${BLUE}Downloading: ${FILE_NAME}${RESET}"
  aws --endpoint-url "$S3_ENDPOINT" s3 cp \
    "s3://${S3_BUCKET}/${S3_PREFIX_PATH}${FILE_NAME}" \
    "$DL_PATH"

  echo -e "${BLUE}Decrypting: ${FILE_NAME}${RESET}"
  gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "$DL_PATH" > "$DEC_PATH"
  rm -f "$DL_PATH"

  echo -e "${BLUE}Replaying oplog chunk: ${FILE_NAME}${RESET}"
  mongorestore \
    --host "$TARGET_HOST" \
    --port "$TARGET_PORT" \
    -u "$TARGET_USER" \
    -p "$TARGET_PASS" \
    --authenticationDatabase "$TARGET_AUTHDB" \
    --archive="$DEC_PATH" \
    --gzip

  rm -f "$DEC_PATH"
done < "$TMP_LIST"

rm -f "$TMP_LIST"

echo -e "${GREEN}Oplog replay completed successfully.${RESET}"
