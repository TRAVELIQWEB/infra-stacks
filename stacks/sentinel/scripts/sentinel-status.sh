#!/usr/bin/env bash
set -e

SENTINEL_PORT=$(docker ps --format '{{.Names}} {{.Ports}}' \
  | grep redis-sentinel \
  | sed -E 's/.*:([0-9]+)->.*/\1/')

if [[ -z "$SENTINEL_PORT" ]]; then
    echo "No sentinel container running!"
    exit 1
fi

echo "=== Redis Sentinel Status (Port $SENTINEL_PORT) ==="

MASTERS=$(redis-cli -p "$SENTINEL_PORT" SENTINEL masters | awk '/name/ {getline; print}')

for NAME in $MASTERS; do
  INFO=$(redis-cli -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  IP=$(echo "$INFO" | awk '/^ip$/ {getline; print}')
  PORT=$(echo "$INFO" | awk '/^port$/ {getline; print}')
  FLAGS=$(echo "$INFO" | awk '/^flags$/ {getline; print}')
  SLAVES=$(echo "$INFO" | awk '/^num-slaves$/ {getline; print}')

  echo ""
  echo "Cluster: $NAME"
  echo "Master : $IP:$PORT"
  echo "Flags  : $FLAGS"
  echo "Slaves : $SLAVES"
done
