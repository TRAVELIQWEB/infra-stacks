#!/usr/bin/env bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

echo -e "${BLUE}======================================================"
echo -e "                  Redis Instance Status               "
echo -e "======================================================${RESET}\n"

for DIR in /opt/redis-stack-*; do
  [[ ! -d "$DIR" ]] && continue

  ENV_FILE="$DIR/.env"
  [[ ! -f "$ENV_FILE" ]] && continue

  PORT=$(grep HOST_PORT "$ENV_FILE" | cut -d '=' -f2)
  ROLE=$(grep ROLE "$ENV_FILE" | cut -d '=' -f2)
  MASTER_IP=$(grep MASTER_IP "$ENV_FILE" | cut -d '=' -f2)
  MASTER_PORT=$(grep MASTER_PORT "$ENV_FILE" | cut -d '=' -f2)

  STATUS=$(redis-cli -p "$PORT" ping 2>/dev/null || echo "DOWN")

  if [[ "$STATUS" == "PONG" ]]; then
    STATUS="${GREEN}UP${RESET}"
  else
    STATUS="${RED}DOWN${RESET}"
  fi

  echo -e "${YELLOW}------------------------------------------------------${RESET}"
  echo -e "Instance        : redis-stack-${PORT}"
  echo -e "Port            : ${BLUE}${PORT}${RESET}"
  echo -e "Role            : ${GREEN}${ROLE}${RESET}"
  
  if [[ "$ROLE" == "replica" ]]; then
    echo -e "Master Followed : ${BLUE}${MASTER_IP}:${MASTER_PORT}${RESET}"
  fi

  echo -e "Status          : $STATUS"

done

echo ""
echo -e "${GREEN}✔ Redis instance scan completed${RESET}\n"
