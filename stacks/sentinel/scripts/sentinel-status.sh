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

# -------------------------------
# Ask for Sentinel password
# -------------------------------
read -s -p "Enter Sentinel password: " SENTINEL_PASSWORD
echo ""

if [[ -z "$SENTINEL_PASSWORD" ]]; then
  echo "❌ Sentinel password required"
  exit 1
fi

# -------------------------------
# Get master names
# -------------------------------
MASTER_NAMES=$(redis-cli \
  -a "$SENTINEL_PASSWORD" \        # ✅ AUTH ADDED
  --raw -p "$SENTINEL_PORT" \
  SENTINEL masters \
  | grep '^redis-' || true)

if [[ -z "$MASTER_NAMES" ]]; then
    echo "⚠ No masters detected"
    exit 0
fi

for NAME in $MASTER_NAMES; do
  # Query details for each master
  INFO=$(redis-cli \
    -a "$SENTINEL_PASSWORD" \      # ✅ AUTH ADDED
    --raw -p "$SENTINEL_PORT" \
    SENTINEL master "$NAME")

  get() {
    echo "$INFO" | grep -A1 "^$1$" | tail -n1
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
