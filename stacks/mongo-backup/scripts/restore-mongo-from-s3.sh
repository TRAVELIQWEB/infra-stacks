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
# Load backup config
###########################################
CONFIG_FILE="/opt/mongo-backups/backup-config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Backup config file not found: $CONFIG_FILE${RESET}"
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$S3_REGION"

###########################################
# Ask user which port to restore
###########################################
echo -e "${YELLOW}Mongo Ports Available For Restore:${RESET}"
for PORT in $MONGO_PORTS; do
    echo " - $PORT"
done

read -rp "Enter Mongo port you want to restore: " RESTORE_PORT

if ! echo "$MONGO_PORTS" | grep -qw "$RESTORE_PORT"; then
    echo -e "${RED}Port $RESTORE_PORT not found in config.${RESET}"
    exit 1
fi

###########################################
# Pickup Restore Mode (daily or monthly)
###########################################
read -rp "Restore type? (daily/monthly): " MODE
if [[ "$MODE" != "daily" && "$MODE" != "monthly" ]]; then
    echo -e "${RED}Invalid mode. Choose daily or monthly.${RESET}"
    exit 1
fi

###########################################
# Fetch available backups from S3
###########################################
PREFIX="${S3_PREFIX}/${RESTORE_PORT}/${MODE}/"

echo -e "${BLUE}Fetching backup list from S3...${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > /tmp/s3list.txt

if ! [[ -s /tmp/s3list.txt ]]; then
    echo -e "${RED}No backups found in S3 for this port/mode.${RESET}"
    exit 1
fi

echo -e "${GREEN}Available backups:${RESET}"
nl -w2 -s". " /tmp/s3list.txt

###########################################
# Ask user which backup to restore
###########################################
read -rp "Enter file index to restore: " FILE_INDEX

FILE_NAME=$(sed -n "${FILE_INDEX}p" /tmp/s3list.txt | awk '{print $4}')

if [[ -z "$FILE_NAME" ]]; then
    echo -e "${RED}Invalid selection.${RESET}"
    exit 1
fi

echo -e "${BLUE}Selected backup: ${FILE_NAME}${RESET}"

###########################################
# Download backup
###########################################
DOWNLOAD_PATH="/opt/mongo-backups/tmp/${FILE_NAME}"

echo -e "${YELLOW}Downloading backup from S3...${RESET}"

aws --endpoint-url "$S3_ENDPOINT" s3 cp \
    "s3://${S3_BUCKET}/${PREFIX}${FILE_NAME}" \
    "$DOWNLOAD_PATH"

###########################################
# Decrypt backup
###########################################
DECRYPTED="${DOWNLOAD_PATH%.gpg}"

echo -e "${YELLOW}Decrypting backup...${RESET}"

gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "$DOWNLOAD_PATH" > "$DECRYPTED"

###########################################
# Extract archive
###########################################
EXTRACT_DIR="/opt/mongo-backups/tmp/restore-${RESTORE_PORT}"

echo -e "${YELLOW}Extracting compressed archive...${RESET}"

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

gunzip -c "$DECRYPTED" > "${EXTRACT_DIR}/dump.archive"

###########################################
# Ask for Target Mongo container/host
###########################################
read -rp "Target Mongo host (default: 127.0.0.1): " TARGET_HOST
[ -z "$TARGET_HOST" ] && TARGET_HOST="127.0.0.1"

read -rp "Target Mongo port (default: $RESTORE_PORT): " TARGET_PORT
[ -z "$TARGET_PORT" ] && TARGET_PORT="$RESTORE_PORT"

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
  --archive="${EXTRACT_DIR}/dump.archive" \
  --gzip \
  --drop

echo -e "${GREEN}Restore completed successfully!${RESET}"

###########################################
# Cleanup temp files
###########################################
rm -f "$DOWNLOAD_PATH" "$DECRYPTED"
rm -rf "$EXTRACT_DIR"

echo -e "${BLUE}Temporary files cleaned.${RESET}"
