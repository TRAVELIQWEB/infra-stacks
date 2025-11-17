#!/usr/bin/env bash
set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Detect sentinel port automatically (first running sentinel)
detect_sentinel_port() {
  local port
  port=$(docker ps --format '{{.Names}} {{.Ports}}' | grep redis-sentinel | sed -E 's/.*:([0-9]+)->.*/\1/')
  
  if [[ -z "$port" ]]; then
    echo -e "${RED}No running sentinel container found!${RESET}"
    exit 1
  fi

  echo "$port"
}

SENTINEL_PORT=$(detect_sentinel_port)

echo -e "${BLUE}==============================================="
echo -e "       Redis Sentinel Status Dashboard         "
echo -e "===============================================${RESET}"
echo -e "Sentinel Port: ${YELLOW}$SENTINEL_PORT${RESET}"
echo ""

# 1. List monitored masters
echo -e "${BLUE}→ Fetching monitored clusters...${RESET}"
MASTERS=$(redis-cli -p "$SENTINEL_PORT" SENTINEL masters | grep -E 'name' | awk '{print $2}')

if [[ -z "$MASTERS" ]]; then
  echo -e "${RED}No clusters monitored by this sentinel!${RESET}"
  exit 1
fi

for NAME in $MASTERS; do
  echo -e "${YELLOW}--------------------------------------------------${RESET}"
  echo -e "${GREEN}Cluster: $NAME${RESET}"

  INFO=$(redis-cli -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  MASTER_IP=$(echo "$INFO" | grep -w ip | awk '{print $2}')
  MASTER_PORT=$(echo "$INFO" | grep -w port | awk '{print $2}')
  FLAGS=$(echo "$INFO" | grep -w flags | awk '{print $2}')
  QUORUM=$(echo "$INFO" | grep -w quorum | awk '{print $2}')
  FAILOVER=$(echo "$INFO" | grep -w failover-state | awk '{print $2}')

  if [[ "$FLAGS" == *"s_down"* ]]; then
    STATUS="${RED}DOWN${RESET}"
  else
    STATUS="${GREEN}UP${RESET}"
  fi

  echo ""
  echo -e "Master IP:      ${BLUE}$MASTER_IP${RESET}"
  echo -e "Master Port:    ${BLUE}$MASTER_PORT${RESET}"
  echo -e "Master Status:  $STATUS"
  echo -e "Quorum Needed:  ${YELLOW}$QUORUM${RESET}"
  echo -e "Failover State: ${YELLOW}${FAILOVER:-none}${RESET}"

  # 2. Show replicas for each master
  echo ""
  echo -e "${BLUE}Replicas:${RESET}"

  SLAVES=$(redis-cli -p "$SENTINEL_PORT" SENTINEL slaves "$NAME" | grep -w ip | awk '{print $2}')

  if [[ -z "$SLAVES" ]]; then
    echo -e "${RED}  No replicas found!${RESET}"
  else
    for SLAVE in $SLAVES; do
      echo -e "  - ${GREEN}${SLAVE}${RESET}"
    done
  fi

  echo ""
done

echo -e "${YELLOW}--------------------------------------------------${RESET}"
echo -e "${GREEN}✔ Sentinel dashboard displayed successfully.${RESET}"
echo ""
