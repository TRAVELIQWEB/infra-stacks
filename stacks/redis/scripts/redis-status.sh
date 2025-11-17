#!/usr/bin/env bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "                  Redis Instance Status"
echo -e "======================================================${RESET}"

for DIR in /opt/redis-stack-*; do
    [[ ! -d "$DIR" ]] && continue

    ENV_FILE="$DIR/.env"
    [[ ! -f "$ENV_FILE" ]] && continue

    NAME=$(basename "$DIR")
    PORT=$(grep "^HOST_PORT=" "$ENV_FILE" | cut -d '=' -f2)
    UI_PORT=$(grep "^HOST_PORT_UI=" "$ENV_FILE" | cut -d '=' -f2)
    ROLE=$(grep "^ROLE=" "$ENV_FILE" | cut -d '=' -f2)
    PASS=$(grep "^REDIS_PASSWORD=" "$ENV_FILE" | cut -d '=' -f2)

    # Ping Redis using password
    STATUS="DOWN"
    if redis-cli -a "$PASS" -p "$PORT" PING &>/dev/null; then
        STATUS="${GREEN}UP${RESET}"
    else
        STATUS="${RED}DOWN${RESET}"
    fi

    echo -e "${YELLOW}------------------------------------------------------${RESET}"
    echo -e "Instance       : ${GREEN}$NAME${RESET}"
    echo -e "Port           : ${BLUE}$PORT${RESET}"
    echo -e "UI Port        : ${BLUE}$UI_PORT${RESET}"
    echo -e "Role           : ${GREEN}$ROLE${RESET}"
    echo -e "Status         : $STATUS"

    if [[ "$ROLE" == "replica" ]]; then
        MASTER_IP=$(grep "^MASTER_IP=" "$ENV_FILE" | cut -d '=' -f2)
        MASTER_PORT=$(grep "^MASTER_PORT=" "$ENV_FILE" | cut -d '=' -f2)
        echo -e "Replica of     : ${GREEN}${MASTER_IP}:${MASTER_PORT}${RESET}"
    fi

done

echo -e "\n${GREEN}✔ Redis instance scan completed${RESET}\n"
