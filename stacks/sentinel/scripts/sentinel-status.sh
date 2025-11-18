#!/usr/bin/env bash
set -e

# Detect sentinel port
SENTINEL_PORT=$(docker ps --format '{{.Names}} {{.Ports}}' \
  | grep "redis-sentinel-" \
  | sed -E 's/.*:([0-9]+)->.*/\1/')

if [[ -z "$SENTINEL_PORT" ]]; then
    echo "❌ No sentinel container running!"
    exit 1
fi

echo "=== Redis Sentinel Status (Port $SENTINEL_PORT) ==="

# Get master names only (raw mode)
MASTER_NAMES=$(redis-cli --raw -p "$SENTINEL_PORT" SENTINEL masters \
  | grep '^redis-' || true)

if [[ -z "$MASTER_NAMES" ]]; then
    echo "⚠ No masters detected (retrying with full parse)..."
fi

for NAME in $MASTER_NAMES; do
  # Query details for each master
  INFO=$(redis-cli --raw -p "$SENTINEL_PORT" SENTINEL master "$NAME")

  # Extract fields directly by key
  get() {
    echo "$INFO" \
      | grep -A1 "^$1$" \
      | tail -n1
  }

  IP=$(get ip)
  PORT=$(get port)
  SLAVES=$(get num-slaves)
  SENTINELS=$(get num-other-sentinels)
  FLAGS=$(get flags)
  EPOCH=$(get config-epoch)

  echo ""
  echo "Cluster:      $NAME"
  echo "Master:       $IP:$PORT"
  echo "Flags:        $FLAGS"
  echo "Slaves:       $SLAVES"
  echo "Sentinels:    $SENTINELS"
  echo "Epoch:        $EPOCH"
done
