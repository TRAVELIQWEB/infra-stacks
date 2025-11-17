#!/usr/bin/env bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
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

echo -e "${BLUE}======================================================"
echo -e "              Redis Sentinel Status Dashboard         "
echo -e "======================================================${RESET}"
echo -e "Sentinel Port: ${YELLOW}$SENTINEL_PORT${RESET}\n"


MASTERS=$(redis-cli -p "$SENTINEL_PORT" SENTINEL masters \
  | awk '/"name"/ {getline; print $2}' | tr -d '"')


if [[ -z "$MASTERS" ]]; then
  echo -e "${RED}No clusters detected by Sentinel.${RESET}"
  echo -e "Check: redis-cli -p $SENTINEL_PORT SENTINEL masters\n"
  exit 0
fi

for NAME in $MASTERS; do

  INFO=$(redis-cli -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  MASTER_IP=$(echo "$INFO" | grep -w ip | awk '{print $2}')
  MASTER_PORT=$(echo "$INFO" | grep -w port | awk '{print $2}')
  FLAGS=$(echo "$INFO" | grep -w flags | awk '{print $2}')
  SLAVE_COUNT=$(echo "$INFO" | grep -w num-slaves | awk '{print $2}')
  QUORUM=$(echo "$INFO" | grep -w quorum | awk '{print $2}')
  FAIL_TIMEOUT=$(echo "$INFO" | grep -w failover-timeout | awk '{print $2}')
  PARALLEL_SYNC=$(echo "$INFO" | grep -w parallel-syncs | awk '{print $2}')

  STATUS="${GREEN}UP${RESET}"
  [[ "$FLAGS" == *"s_down"* ]] && STATUS="${RED}DOWN${RESET}"
  [[ "$FLAGS" == *"disconnected"* ]] && STATUS="${RED}DISCONNECTED${RESET}"

  echo -e "${YELLOW}------------------------------------------------------${RESET}"
  echo -e "Cluster Name     : ${GREEN}${NAME}${RESET}"
  echo -e "Master Node      : ${BLUE}${MASTER_IP}:${MASTER_PORT}${RESET}"
  echo -e "Master Status    : $STATUS"
  echo -e "Replica Count    : ${CYAN}${SLAVE_COUNT}${RESET}"
  echo -e "Quorum Required  : ${YELLOW}${QUORUM}${RESET}"
  echo -e "Failover Timeout : ${YELLOW}${FAIL_TIMEOUT} ms${RESET}"
  echo -e "Parallel Syncs   : ${CYAN}${PARALLEL_SYNC}${RESET}\n"

  echo -e "${BLUE}Replica Nodes:${RESET}"

  redis-cli -p "$SENTINEL_PORT" SENTINEL slaves "$NAME" \
    | grep -E "ip|port|flags" \
    | awk '
      /ip/ { ip=$2 }
      /port/ { port=$2 }
      /flags/ {
        status="UP"
        if ($2 ~ /s_down/) status="DOWN"
        if ($2 ~ /disconnected/) status="DISCONNECTED"
        printf "  - %s:%s (%s)\n", ip, port, status
      }
    '

  echo ""
done

echo -e "${GREEN}✔ Dashboard ready.${RESET}\n"
