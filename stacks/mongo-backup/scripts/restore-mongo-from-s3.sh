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
      "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.9.4.deb"

    sudo apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"

    if ! command -v mongorestore >/dev/null 2>&1; then
        echo -e "${RED}Mongo tools installation failed!${RESET}"
        exit 1
    fi
fi

if [ "$NEED_MONGOSH" = true ]; then
    echo -e "${YELLOW}Installing MongoDB Shell (mongosh)...${RESET}"
    
    # Install MongoDB Shell
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update
    sudo apt install -y mongodb-mongosh
    
    if command -v mongosh >/dev/null 2>&1; then
        echo -e "${GREEN}MongoDB Shell installed successfully.${RESET}"
    else
        echo -e "${RED}MongoDB Shell installation failed!${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}MongoDB Shell already installed.${RESET}"
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
# 9) Restore - Simple Approach
###############################################
echo -e "${BLUE}Restoring into ${HOST}:${PORT}...${RESET}"

# First, let's check what's in the backup by extracting it temporarily
echo -e "${YELLOW}Checking backup contents...${RESET}"

# Extract to directory format to see databases
EXTRACT_DIR="${TMP_DIR}/extract"
mkdir -p "$EXTRACT_DIR"

# Convert archive to directory format to see what databases are included
mongorestore \
  --archive="$DEC" \
  --gzip \
  --dir="$EXTRACT_DIR" \
  --dryRun > /dev/null 2>&1 || true

# List the databases found
if [ -d "$EXTRACT_DIR" ]; then
    echo -e "${GREEN}Databases found in backup:${RESET}"
    find "$EXTRACT_DIR" -maxdepth 1 -type d -name "*.bson" -o -name "*" | grep -v "^$EXTRACT_DIR$" | while read -r dir; do
        db_name=$(basename "$dir")
        if [ -n "$db_name" ] && [ "$db_name" != "extract" ]; then
            echo "  - $db_name"
        fi
    done
fi

# Ask user which database to restore or restore all application dbs
echo -e "${YELLOW}Choose restore option:${RESET}"
echo "1) Restore ALL databases (including system dbs - may cause version conflicts)"
echo "2) Restore only application databases (saarthi-prod-db)"
read -rp "Enter choice (1 or 2): " RESTORE_CHOICE

if [ "$RESTORE_CHOICE" = "2" ]; then
    echo -e "${YELLOW}Restoring only saarthi-prod-db...${RESET}"
    mongorestore \
      --host "$HOST" \
      --port "$PORT" \
      -u "$USER" \
      -p "$PASS" \
      --authenticationDatabase "$AUTH" \
      --archive="$DEC" \
      --gzip \
      --nsInclude="saarthi-prod-db.*" \
      --drop
else
    echo -e "${YELLOW}Restoring ALL databases...${RESET}"
    echo -e "${RED}Warning: This may cause version conflicts with system databases${RESET}"
    
    # Try to restore everything, but skip if system version conflicts occur
    mongorestore \
      --host "$HOST" \
      --port "$PORT" \
      -u "$USER" \
      -p "$PASS" \
      --authenticationDatabase "$AUTH" \
      --archive="$DEC" \
      --gzip \
      --drop \
      --stopOnError || echo -e "${YELLOW}Some errors occurred but continuing...${RESET}"
fi

echo -e "${GREEN}Restore Completed Successfully!${RESET}"

###############################################
# 10) Cleanup
###############################################
rm -rf "$TMP_DIR"
echo -e "${BLUE}Temporary files cleaned.${RESET}"