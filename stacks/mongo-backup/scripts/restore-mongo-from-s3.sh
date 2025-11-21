#!/usr/bin/env bash
set -e

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}====================================================="
echo -e "                 MongoDB Restore Script"
echo -e "=====================================================${RESET}"

###########################################
# Load per-port backup config
###########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup-config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Backup config file not found: ${CONFIG_FILE}${RESET}"
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

echo -e "${GREEN}Loaded config for Mongo Port: ${MONGO_PORT}${RESET}"
echo -e "${GREEN}Project Prefix: ${S3_PREFIX}${RESET}"
echo ""

###########################################
# Select restore type
###########################################
read -rp "Restore type? (daily/monthly): " MODE

if [[ "$MODE" != "daily" && "$MODE" != "monthly" ]]; then
    echo -e "${RED}Invalid mode. Choose daily or monthly.${RESET}"
    exit 1
fi

###########################################
# Fetch available backups from S3
###########################################

PREFIX="${S3_PREFIX}/${MONGO_PORT}/${MODE}/"
TMP_LIST="${TMP_DIR}/restore-list-${MODE}.txt"
mkdir -p "$TMP_DIR"

echo -e "${BLUE}Fetching backup list: s3://${S3_BUCKET}/${PREFIX}${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > "$TMP_LIST" || true

if ! [[ -s "$TMP_LIST" ]]; then
    echo -e "${RED}No backups found in S3 for this port/mode.${RESET}"
    exit 1
fi

echo -e "${GREEN}Available backups:${RESET}"
nl -w2 -s". " "$TMP_LIST"

###########################################
# Ask user which backup index to restore
###########################################
read -rp "Enter backup index to restore: " FILE_INDEX

FILE_NAME=$(sed -n "${FILE_INDEX}p" "$TMP_LIST" | awk '{print $4}')

if [[ -z "$FILE_NAME" ]]; then
    echo -e "${RED}Invalid selection.${RESET}"
    exit 1
fi

DOWNLOAD_PATH="${TMP_DIR}/${FILE_NAME}"

echo -e "${BLUE}Selected backup: ${FILE_NAME}${RESET}"

###########################################
# Download backup
###########################################
echo -e "${YELLOW}Downloading file from S3...${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 cp \
    "s3://${S3_BUCKET}/${PREFIX}${FILE_NAME}" \
    "$DOWNLOAD_PATH"

###########################################
# Decrypt backup (keeps .gz)
###########################################
DECRYPTED="${DOWNLOAD_PATH%.gpg}"

echo -e "${YELLOW}Decrypting backup...${RESET}"

gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "$DOWNLOAD_PATH" > "$DECRYPTED"

###########################################
# Ask user for restore target
###########################################
echo ""
echo -e "${BLUE}Enter TARGET MongoDB details (where to restore)${RESET}"

read -rp "Target Host (default: 127.0.0.1): " TARGET_HOST
[ -z "$TARGET_HOST" ] && TARGET_HOST="127.0.0.1"

read -rp "Target Port (default: ${MONGO_PORT}): " TARGET_PORT
[ -z "$TARGET_PORT" ] && TARGET_PORT="$MONGO_PORT"

read -rp "Target Username: " TARGET_USER
read -rp "Target Password: " TARGET_PASS

read -rp "Target Auth DB (default: admin): " TARGET_AUTHDB
[ -z "$TARGET_AUTHDB" ] && TARGET_AUTHDB="admin"

###########################################
# Restore into target MongoDB
###########################################
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

echo -e "${GREEN}Restore completed successfully!${RESET}"

###########################################
# Clean temp files
###########################################
rm -f "$DOWNLOAD_PATH" "$DECRYPTED" "$TMP_LIST"

echo -e "${BLUE}Temporary files cleaned.${RESET}"
