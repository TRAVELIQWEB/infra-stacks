#!/usr/bin/env bash
set -e

BLUE="\e[34m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"

echo -e "${BLUE}====================================================="
echo -e "             MongoDB Restore from S3 (Full)"
echo -e "       Data + Indexes in a single mongorestore"
echo -e "=====================================================${RESET}"


###############################################
# 0) Auto Install Dependencies
###############################################
echo -e "${BLUE}Checking required dependencies...${RESET}"

NEED_INSTALL=()

command -v aws >/dev/null 2>&1 || NEED_INSTALL+=("awscli")
command -v gpg >/dev/null 2>&1 || NEED_INSTALL+=("gpg")

if ! command -v mongorestore >/dev/null 2>&1; then
    NEED_MONGO_TOOLS=true
else
    NEED_MONGO_TOOLS=false
fi

# Check for mongosh
if ! command -v mongosh >/dev/null 2>&1; then
    NEED_MONGOSH=true
else
    NEED_MONGOSH=false
fi

if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${NEED_INSTALL[*]}${RESET}"
    sudo apt update -y
    sudo apt install -y "${NEED_INSTALL[@]}"
else
    echo -e "${GREEN}awscli + gpg OK${RESET}"
fi

if [ "$NEED_MONGO_TOOLS" = true ]; then
    echo -e "${YELLOW}Installing MongoDB Tools (mongorestore)...${RESET}"

    TMP_DEB="/tmp/mongodb-tools.deb"
    wget -qO "$TMP_DEB" \
      "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.13.0.deb"

    sudo apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"

    if ! command -v mongorestore >/dev/null 2>&1; then
        echo -e "${RED}Mongo tools installation failed!${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}MongoDB Tools already installed.${RESET}"
fi



echo -e "${GREEN}All required tools installed.${RESET}"


###############################################
# 1) Ask Mongo Port (used in S3 path only)
###############################################
read -rp "Enter Mongo Port used in backup path (e.g., 27017, 27019): " MONGO_PORT


###############################################
# 2) Ask S3 / Zata Details
###############################################
echo -e "\n${BLUE}--- S3 / Zata Settings ---${RESET}"

read -rp "S3 Endpoint (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

read -rp "S3 Bucket Name: " S3_BUCKET
read -rp "S3 Prefix (wallet/fwms/rail/dev/prod/...): " S3_PREFIX

read -rp "S3 Region (default: ap-south-1): " S3_REGION
[ -z "$S3_REGION" ] && S3_REGION="ap-south-1"

echo -e "\n${YELLOW}--- Access Keys ---${RESET}"
read -rp "Access Key ID: " AWS_ACCESS_KEY_ID
read -rp "Secret Access Key: " AWS_SECRET_ACCESS_KEY

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="$S3_REGION"


###############################################
# 3) Encryption
###############################################
read -rp "Encryption Passphrase: " ENC_PASS


###############################################
# 4) Restore Type
###############################################
read -rp "Restore type? (daily/monthly): " MODE
if [[ "$MODE" != "daily" && "$MODE" != "monthly" ]]; then
    echo -e "${RED}Invalid mode. Use 'daily' or 'monthly'.${RESET}"
    exit 1
fi


###############################################
# 5) List Backups in S3
###############################################
PREFIX="${S3_PREFIX}/${MONGO_PORT}/${MODE}/"

TMP_DIR="/tmp/mongo-restore-$MONGO_PORT"
mkdir -p "$TMP_DIR"

TMP_LIST="$TMP_DIR/list.txt"

echo -e "${BLUE}Fetching backups from: s3://${S3_BUCKET}/${PREFIX}${RESET}"
aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > "$TMP_LIST" 2>/dev/null || true

if ! [[ -s "$TMP_LIST" ]]; then
  echo -e "${RED}No backups found at s3://${S3_BUCKET}/${PREFIX}${RESET}"
  exit 1
fi

echo -e "${GREEN}Available backups:${RESET}"
nl -w2 -s". " "$TMP_LIST"


###############################################
# 6) Select Backup
###############################################
read -rp "Enter backup index to restore: " N
FILE=$(sed -n "${N}p" "$TMP_LIST" | awk '{print $4}')

if [ -z "$FILE" ]; then
    echo -e "${RED}Invalid selection.${RESET}"
    exit 1
fi

echo -e "${BLUE}Selected backup file: $FILE${RESET}"


###############################################
# 7) Download + Decrypt
###############################################
DL="${TMP_DIR}/${FILE}"
DEC="${DL%.gpg}"

echo -e "${YELLOW}Downloading backup from S3...${RESET}"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://${S3_BUCKET}/${PREFIX}${FILE}" "$DL"

echo -e "${YELLOW}Decrypting backup (creating .archive.gz)...${RESET}"
gpg --batch --yes --passphrase "$ENC_PASS" -d "$DL" > "$DEC"

if [ ! -s "$DEC" ]; then
    echo -e "${RED}Decryption failed or produced empty file.${RESET}"
    exit 1
fi

echo -e "${GREEN}Decrypted archive: $DEC${RESET}"


###############################################
# 8) Target Mongo Info
###############################################
echo -e "\n${BLUE}--- TARGET MongoDB (where data will be restored) ---${RESET}"

read -rp "Target Host (default: 127.0.0.1): " HOST
[ -z "$HOST" ] && HOST="127.0.0.1"

read -rp "Target Port (default: ${MONGO_PORT}): " PORT
[ -z "$PORT" ] && PORT="$MONGO_PORT"

read -rp "Username: " USER
read -rp "Password: " PASS
read -rp "Auth DB (default: admin): " AUTH
[ -z "$AUTH" ] && AUTH="admin"


###############################################
# 9) Ask about system DBs (admin/local/config)
###############################################
echo -e "\n${YELLOW}By default, system databases (admin, local, config) will be SKIPPED."
echo -e "This avoids version / user / role conflicts on new clusters.${RESET}"
read -rp "Do you ALSO want to restore system DBs? (y/N): " INCLUDE_SYSTEM
INCLUDE_SYSTEM=$(echo "$INCLUDE_SYSTEM" | tr '[:upper:]' '[:lower:]')

NS_EXCLUDES=()
if [[ "$INCLUDE_SYSTEM" != "y" && "$INCLUDE_SYSTEM" != "yes" ]]; then
    echo -e "${GREEN}System DBs will be skipped (admin/local/config).${RESET}"
    NS_EXCLUDES+=( --nsExclude="admin.*" --nsExclude="local.*" --nsExclude="config.*" )
else
    echo -e "${RED}WARNING: Restoring system DBs may cause version/user/role conflicts!${RESET}"
    echo -e "${YELLOW}Proceeding with FULL restore including admin/local/config...${RESET}"
fi


###############################################
# 10) Single-pass mongorestore (data + indexes)
###############################################
echo -e "\n${BLUE}==== Running mongorestore (DATA + INDEXES) ==== ${RESET}"

RESTORE_CMD=(
  mongorestore
  --host "$HOST"
  --port "$PORT"
  -u "$USER"
  -p "$PASS"
  --authenticationDatabase "$AUTH"
  --archive="$DEC"
  --gzip
  --drop
  "${NS_EXCLUDES[@]}"
)

echo -e "${YELLOW}Command:${RESET} ${RESTORE_CMD[*]}"

# shellcheck disable=SC2068
${RESTORE_CMD[@]} || {
    echo -e "${RED}mongorestore finished with errors. Check logs above.${RESET}"
}

echo -e "${GREEN}Restore process completed (mongorestore exited).${RESET}"


###############################################
# 11) Cleanup
###############################################
echo -e "${BLUE}Cleaning up temporary files...${RESET}"
rm -rf "$TMP_DIR"
echo -e "${GREEN}Temporary files cleaned.${RESET}"
