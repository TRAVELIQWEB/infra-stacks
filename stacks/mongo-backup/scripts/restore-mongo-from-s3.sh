#!/usr/bin/env bash
set -e

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}====================================================="
echo -e "             Standalone MongoDB Restore Script"
echo -e "=====================================================${RESET}"

###############################################
# 1) Ask for Mongo Port (source backup location)
###############################################
read -rp "Enter Mongo Port for this project (e.g., 27017, 27019): " MONGO_PORT

###############################################
# 2) Ask S3 details (FULLY independent)
###############################################
echo -e "\n${BLUE}--- Zata / S3 Settings ---${RESET}"

read -rp "S3 Endpoint URL (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

read -rp "S3 Bucket Name: " S3_BUCKET
read -rp "S3 Folder Prefix (same as backup, e.g., wallet, fwms): " S3_PREFIX

read -rp "S3 Region (default: ap-south-1): " S3_REGION
[ -z "$S3_REGION" ] && S3_REGION="ap-south-1"

echo -e "\n${YELLOW}--- Access Keys ---${RESET}"
read -rp "Access Key ID: " AWS_ACCESS_KEY_ID
read -rp "Secret Access Key: " AWS_SECRET_ACCESS_KEY

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

###############################################
# 3) Ask Encryption Password
###############################################
read -rp "Encryption Passphrase (same as backup): " ENC_PASS

###############################################
# 4) Ask Restore Mode
###############################################
read -rp "Restore type? (daily/monthly): " MODE
if [[ "$MODE" != "daily" && "$MODE" != "monthly" ]]; then
    echo -e "${RED}Invalid mode.${RESET}"
    exit 1
fi

###############################################
# 5) Fetch and list backups
###############################################
PREFIX="${S3_PREFIX}/${MONGO_PORT}/${MODE}/"
TMP_DIR="/tmp/mongo-restore-${MONGO_PORT}"
mkdir -p "$TMP_DIR"

TMP_LIST="${TMP_DIR}/backup-list.txt"

echo -e "${BLUE}Fetching backup list from: s3://${S3_BUCKET}/${PREFIX}${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > "$TMP_LIST" || true

if ! [[ -s "$TMP_LIST" ]]; then
    echo -e "${RED}No backups found.${RESET}"
    exit 1
fi

echo -e "${GREEN}Backups Available:${RESET}"
nl -w2 -s". " "$TMP_LIST"

###############################################
# 6) Pick backup index
###############################################
read -rp "Enter backup index to restore: " FILE_INDEX
FILE_NAME=$(sed -n "${FILE_INDEX}p" "$TMP_LIST" | awk '{print $4}')

if [[ -z "$FILE_NAME" ]]; then
    echo -e "${RED}Invalid selection.${RESET}"
    exit 1
fi

echo -e "${BLUE}Selected backup: ${FILE_NAME}${RESET}"

###############################################
# 7) Download backup
###############################################
DL_PATH="${TMP_DIR}/${FILE_NAME}"

echo -e "${YELLOW}Downloading...${RESET}"
aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://${S3_BUCKET}/${PREFIX}${FILE_NAME}" \
  "$DL_PATH"

###############################################
# 8) Decrypt backup
###############################################
DECRYPTED="${DL_PATH%.gpg}"

echo -e "${YELLOW}Decrypting backup...${RESET}"
gpg --batch --yes --passphrase "$ENC_PASS" -d "$DL_PATH" > "$DECRYPTED"

###############################################
# 9) Target MongoDB details
###############################################
echo -e "\n${BLUE}--- Target MongoDB (where to restore) ---${RESET}"

read -rp "Target Host (default: 127.0.0.1): " TARGET_HOST
[ -z "$TARGET_HOST" ] && TARGET_HOST="127.0.0.1"

read -rp "Target Port (default: ${MONGO_PORT}): " TARGET_PORT
[ -z "$TARGET_PORT" ] && TARGET_PORT="$MONGO_PORT"

read -rp "Target Username: " TARGET_USER
read -rp "Target Password: " TARGET_PASS

read -rp "Target Auth DB (default: admin): " TARGET_AUTHDB
[ -z "$TARGET_AUTHDB" ] && TARGET_AUTHDB="admin"

###############################################
# 10) Perform Restore
###############################################
echo -e "${BLUE}Restoring into ${TARGET_HOST}:${TARGET_PORT} ...${RESET}"

mongorestore \
  --host "$TARGET_HOST" \
  --port "$TARGET_PORT" \
  -u "$TARGET_USER" \
  -p "$TARGET_PASS" \
  --authenticationDatabase "$TARGET_AUTHDB" \
  --archive="$DECRYPTED" \
  --gzip \
  --drop

echo -e "${GREEN}Restore Completed Successfully.${RESET}"

###############################################
# 11) Cleanup
###############################################
rm -f "$DL_PATH" "$DECRYPTED"
rm -rf "$TMP_DIR"

echo -e "${BLUE}Temporary files cleaned.${RESET}"
