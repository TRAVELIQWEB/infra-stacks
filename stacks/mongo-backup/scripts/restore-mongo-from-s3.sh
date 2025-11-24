#!/usr/bin/env bash
set -e

BLUE="\e[34m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"

echo -e "${BLUE}====================================================="
echo -e "             Standalone MongoDB Restore Script"
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
      "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.9.4.deb"

    sudo apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"

    if ! command -v mongorestore >/dev/null 2>&1; then
        echo -e "${RED}Mongo tools installation failed!${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}All required tools installed.${RESET}"

###############################################
# 1) Ask Mongo Port
###############################################
read -rp "Enter Mongo Port for restore (e.g., 27017, 27019): " MONGO_PORT


###############################################
# 2) Ask S3 Details
###############################################
echo -e "\n${BLUE}--- S3 / Zata Settings ---${RESET}"

read -rp "S3 Endpoint (default: https://s3.zata.cloud): " S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && S3_ENDPOINT="https://s3.zata.cloud"

read -rp "S3 Bucket Name: " S3_BUCKET
read -rp "S3 Prefix (wallet/fwms/rail/...): " S3_PREFIX

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
[[ "$MODE" != "daily" && "$MODE" != "monthly" ]] && { echo -e "${RED}Invalid mode${RESET}"; exit 1; }


###############################################
# 5) List Backups
###############################################
PREFIX="${S3_PREFIX}/${MONGO_PORT}/${MODE}/"

TMP_DIR="/tmp/mongo-restore-$MONGO_PORT"
mkdir -p "$TMP_DIR"

TMP_LIST="$TMP_DIR/list.txt"

echo -e "${BLUE}Fetching: s3://${S3_BUCKET}/${PREFIX}${RESET}"
aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/${PREFIX}" > "$TMP_LIST" || true

if ! [[ -s "$TMP_LIST" ]]; then
  echo -e "${RED}No backups found.${RESET}"
  exit 1
fi

echo -e "${GREEN}Backups:${RESET}"
nl -w2 -s". " "$TMP_LIST"


###############################################
# 6) Select Backup
###############################################
read -rp "Enter backup index: " N
FILE=$(sed -n "${N}p" "$TMP_LIST" | awk '{print $4}')

[ -z "$FILE" ] && { echo -e "${RED}Invalid selection${RESET}"; exit 1; }

echo -e "${BLUE}Selected: $FILE${RESET}"


###############################################
# 7) Download + Decrypt
###############################################
DL="${TMP_DIR}/${FILE}"
DEC="${DL%.gpg}"

echo -e "${YELLOW}Downloading...${RESET}"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://${S3_BUCKET}/${PREFIX}${FILE}" "$DL"

echo -e "${YELLOW}Decrypting...${RESET}"
gpg --batch --yes --passphrase "$ENC_PASS" -d "$DL" > "$DEC"


###############################################
# 8) Target Mongo Info
###############################################
echo -e "\n${BLUE}--- TARGET MongoDB ---${RESET}"

read -rp "Target Host (default: 127.0.0.1): " HOST
[ -z "$HOST" ] && HOST="127.0.0.1"

read -rp "Target Port (default: ${MONGO_PORT}): " PORT
[ -z "$PORT" ] && PORT="$MONGO_PORT"

read -rp "Username: " USER
read -rp "Password: " PASS
read -rp "Auth DB (default: admin): " AUTH
[ -z "$AUTH" ] && AUTH="admin"


###############################################
# 9) Restore
###############################################

echo -e "${BLUE}Restoring into ${HOST}:${PORT} with version handling...${RESET}"

# Clean system collections that cause version conflicts
echo -e "${YELLOW}Cleaning system version data to prevent conflicts...${RESET}"

mongosh --quiet \
  --host "$HOST" \
  --port "$PORT" \
  -u "$USER" \
  -p "$PASS" \
  --authenticationDatabase "$AUTH" \
  --eval "
  try { 
    db.getSiblingDB('admin').system.version.drop(); 
    print('✓ Dropped admin.system.version');
  } catch(e) { 
    print('Note: Could not drop admin.system.version:', e.message); 
  }
  try { 
    db.getSiblingDB('admin').system.sessions.drop();
    print('✓ Dropped admin.system.sessions');
  } catch(e) { 
    print('Note: Could not drop admin.system.sessions'); 
  }
  "

# Now perform the restore
mongorestore \
  --host "$HOST" \
  --port "$PORT" \
  -u "$USER" \
  -p "$PASS" \
  --authenticationDatabase "$AUTH" \
  --archive="$DEC" \
  --gzip \
  --drop
echo -e "${GREEN}Restore Completed Successfully.${RESET}"


###############################################
# 10) Cleanup
###############################################
rm -rf "$TMP_DIR"
echo -e "${BLUE}Temporary files cleaned.${RESET}"
