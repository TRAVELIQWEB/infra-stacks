#!/usr/bin/env bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

detect_sentinel_port() {
  docker ps --format '{{.Names}} {{.Ports}}' \
  | grep redis-sentinel \
  | sed -E 's/.*:([0-9]+)->.*/\1/'
}

SENTINEL_PORT=$(detect_sentinel_port)

if [[ -z "$SENTINEL_PORT" ]]; then
  echo -e "${RED}No sentinel container found!${RESET}"
  exit 1
fi

echo -e "${BLUE}==============================================="
echo -e "         Redis Sentinel Status Dashboard       "
echo -e "===============================================${RESET}"

echo -e "Sentinel Port: ${YELLOW}$SENTINEL_PORT${RESET}\n"

MASTERS=$(redis-cli -p "$SENTINEL_PORT" SENTINEL masters | grep name | awk '{print $2}')

for NAME in $MASTERS; do

  INFO=$(redis-cli -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  MASTER_IP=$(echo "$INFO" | grep -w ip | awk '{print $2}')
  MASTER_PORT=$(echo "$INFO" | grep -w port | awk '{print $2}')
  FLAGS=$(echo "$INFO" | grep -w flags | awk '{print $2}')

  STATUS="${GREEN}UP${RESET}"
  [[ "$FLAGS" == *"s_down"* ]] && STATUS="${RED}DOWN${RESET}"

  echo -e "${YELLOW}----------------------------------------------${RESET}"
  echo -e "Cluster: ${GREEN}${NAME}${RESET}"
  echo -e "Master:  ${BLUE}${MASTER_IP}:${MASTER_PORT}${RESET}"
  echo -e "Status:  $STATUS\n"

  echo -e "${BLUE}Replicas:${RESET}"
  redis-cli -p "$SENTINEL_PORT" SENTINEL slaves "$NAME" \
    | grep ip | awk '{print $2}' \
    | sed 's/^/  - /'

  echo ""
done

echo -e "${GREEN}✔ Dashboard ready.${RESET}\n"
