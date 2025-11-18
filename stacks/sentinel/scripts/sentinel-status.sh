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

# ---- FIXED MASTER NAME EXTRACTION ----


MASTERS=$(redis-cli -p "$SENTINEL_PORT" SENTINEL masters \
  | awk '
      $1 == "name" { getline; print $1 }
    ')


if [[ -z "$MASTERS" ]]; then
  echo -e "${RED}No clusters detected by Sentinel.${RESET}"
  echo -e "Check: redis-cli -p $SENTINEL_PORT SENTINEL masters\n"
  exit 0
fi

for NAME in $MASTERS; do

  INFO=$(redis-cli -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  MASTER_IP=$(echo "$INFO" | awk '/^ip$/ {getline; print}')
  MASTER_PORT=$(echo "$INFO" | awk '/^port$/ {getline; print}')
  FLAGS=$(echo "$INFO" | awk '/^flags$/ {getline; print}')
  SLAVE_COUNT=$(echo "$INFO" | awk '/^num-slaves$/ {getline; print}')
  QUORUM=$(echo "$INFO" | awk '/^quorum$/ {getline; print}')
  FAIL_TIMEOUT=$(echo "$INFO" | awk '/^failover-timeout$/ {getline; print}')
  PARALLEL_SYNC=$(echo "$INFO" | awk '/^parallel-syncs$/ {getline; print}')

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
    | awk '
      /^ip$/ { getline; ip=$0 }
      /^port$/ { getline; port=$0 }
      /^flags$/ {
        getline
        status="UP"
        if ($0 ~ /s_down/) status="DOWN"
        if ($0 ~ /disconnected/) status="DISCONNECTED"
        printf "  - %s:%s (%s)\n", ip, port, status
      }
    '

  echo ""
done

echo -e "${GREEN}✔ Dashboard ready.${RESET}\n"
