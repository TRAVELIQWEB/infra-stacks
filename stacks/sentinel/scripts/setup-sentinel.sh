#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_DIR="$(cd "$STACK_DIR/../.." && pwd)"
TEMPLATE_DIR="$STACK_DIR/templates"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "Setting up Redis Sentinel"

SENTINEL_PORT=$(ask "Enter sentinel port (default 26379):")
[[ -z "$SENTINEL_PORT" ]] && SENTINEL_PORT=26379

CONF_DIR="/opt/redis-sentinel"
CONF_FILE="${CONF_DIR}/sentinel-${SENTINEL_PORT}.conf"
safe_mkdir "$CONF_DIR"

# Base template only defines port + dir
env SENTINEL_PORT="$SENTINEL_PORT" \
  envsubst < "$TEMPLATE_DIR/sentinel.conf.tpl" > "$CONF_FILE"

info ""
info "🛰  Scanning Redis clusters under /opt/redis-stack-* ..."
info ""

for INSTANCE_DIR in /opt/redis-stack-*; do
  [[ ! -d "$INSTANCE_DIR" ]] && continue

  ENV_FILE="$INSTANCE_DIR/.env"
  [[ ! -f "$ENV_FILE" ]] && continue

  PORT=$(grep "^HOST_PORT=" "$ENV_FILE" | cut -d '=' -f2)
  PASS=$(grep "^REDIS_PASSWORD=" "$ENV_FILE" | cut -d '=' -f2)
  ROLE=$(grep "^ROLE=" "$ENV_FILE" | cut -d '=' -f2)
  MASTER_IP=$(grep "^MASTER_IP=" "$ENV_FILE" | cut -d '=' -f2)
  MASTER_PORT=$(grep "^MASTER_PORT=" "$ENV_FILE" | cut -d '=' -f2)

  # If this is a master instance
  if [[ "$ROLE" == "master" ]]; then
    TARGET_IP=$(hostname -I | awk '{print $1}')
    TARGET_PORT="$PORT"
  else
    # If replica, use original master of this specific cluster
    TARGET_IP="$MASTER_IP"
    TARGET_PORT="$MASTER_PORT"
  fi

  info "→ Adding cluster redis-$PORT  master=${TARGET_IP}:${TARGET_PORT}"

  cat >> "$CONF_FILE" <<EOF

# ---- CLUSTER $PORT ----
sentinel monitor redis-${PORT} ${TARGET_IP} ${TARGET_PORT} 2
sentinel auth-pass redis-${PORT} ${PASS}
EOF

done

info "Generated sentinel config at: $CONF_FILE"

TMP_ENV="/tmp/sentinel-${SENTINEL_PORT}.env"
echo "SENTINEL_PORT=$SENTINEL_PORT" > "$TMP_ENV"
echo "CONF_FILE=$CONF_FILE" >> "$TMP_ENV"

info "Starting Sentinel container..."

docker compose \
  -f "$TEMPLATE_DIR/sentinel-docker-compose.yml" \
  --env-file "$TMP_ENV" \
  up -d

success "🚀 Sentinel started on port $SENTINEL_PORT"
echo "✔ Now monitoring all Redis clusters"
