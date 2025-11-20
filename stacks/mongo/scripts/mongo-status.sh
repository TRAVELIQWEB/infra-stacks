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

# Find all running mongo containers
containers=$(docker ps --format '{{.Names}}' | grep '^mongo-' || true)

if [[ -z "$containers" ]]; then
    echo -e "${RED}No MongoDB instances found.${RESET}"
    exit 0
fi

for c in $containers; do
    PORT=$(echo $c | cut -d '-' -f2)

    echo -e "\n${YELLOW}---- Instance: $c  (Port: $PORT) ----${RESET}"

    # Check container health
    if ! docker exec $c mongosh --port $PORT --eval "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        echo -e "${RED}Status: DOWN${RESET}"
        continue
    fi

    echo -e "${GREEN}Status: UP${RESET}"

    # Fetch replica set info
    ROLE=$(docker exec $c mongosh --quiet --port $PORT \
        --eval "rs.status().myState" 2>/dev/null || echo "0")

    case $ROLE in
        1) ROLE_STR="PRIMARY" ;;
        2) ROLE_STR="SECONDARY" ;;
        *) ROLE_STR="UNKNOWN" ;;
    esac

    RS_NAME=$(docker exec $c mongosh --quiet --port $PORT \
        --eval "rs.status().set" 2>/dev/null || echo "-")

    echo -e "Replica Set: ${GREEN}$RS_NAME${RESET}"
    echo -e "Role       : ${GREEN}$ROLE_STR${RESET}"

    # Show hostname inside the cluster
    HOSTNAME=$(docker exec $c mongosh --quiet --port $PORT \
        --eval "db.serverStatus().host" 2>/dev/null || echo "-")

    echo -e "Host       : ${BLUE}$HOSTNAME${RESET}"

done

echo -e "\n${BLUE}======================================================"
echo -e "                     DONE"
echo -e "======================================================${RESET}"
