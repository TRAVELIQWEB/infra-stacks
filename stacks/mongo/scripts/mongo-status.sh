#!/usr/bin/env bash

set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "                 MongoDB Replica Status"
echo -e "======================================================${RESET}"

containers=$(docker ps --format '{{.Names}}' | grep '^mongo-' || true)

if [[ -z "$containers" ]]; then
    echo -e "${RED}No MongoDB instances found.${RESET}"
    exit 0
fi

for c in $containers; do
    PORT=$(echo $c | cut -d '-' -f2)
    ENV_FILE="/opt/mongo-${PORT}/.env"

    echo -e "\n${YELLOW}---- Instance: $c  (Port: $PORT) ----${RESET}"

    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Missing .env file: $ENV_FILE${RESET}"
        continue
    fi

    USER=$(grep '^MONGO_ROOT_USER=' "$ENV_FILE" | cut -d '=' -f2)
    PASS=$(grep '^MONGO_ROOT_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2)

    # Check UP/DOWN
    if ! docker exec $c mongosh --quiet \
        --port $PORT \
        -u "$USER" -p "$PASS" \
        --authenticationDatabase admin \
        --eval "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        echo -e "${RED}Status: DOWN${RESET}"
        continue
    fi

    echo -e "${GREEN}Status: UP${RESET}"

    # Get replica set name
    RS_NAME=$(docker exec $c mongosh --quiet --port $PORT \
        -u "$USER" -p "$PASS" \
        --authenticationDatabase admin \
        --eval "rs.status().set" 2>/dev/null || echo "-")

    echo -e "Replica Set: ${GREEN}$RS_NAME${RESET}"

    # Get role
    ROLE=$(docker exec $c mongosh --quiet --port $PORT \
        -u "$USER" -p "$PASS" \
        --authenticationDatabase admin \
        --eval "rs.status().myState" 2>/dev/null || echo "0")

    case $ROLE in
        1) ROLE_STR="PRIMARY" ;;
        2) ROLE_STR="SECONDARY" ;;
        *) ROLE_STR="UNKNOWN" ;;
    esac

    echo -e "Role       : ${GREEN}$ROLE_STR${RESET}"

    # Hostname
    HOSTNAME=$(docker exec $c mongosh --quiet --port $PORT \
        -u "$USER" -p "$PASS" \
        --authenticationDatabase admin \
        --eval "db.serverStatus().host" 2>/dev/null || echo "-")

    echo -e "Host       : ${BLUE}$HOSTNAME${RESET}"

done

echo -e "\n${BLUE}======================================================"
echo -e "                     DONE"
echo -e "======================================================${RESET}"
