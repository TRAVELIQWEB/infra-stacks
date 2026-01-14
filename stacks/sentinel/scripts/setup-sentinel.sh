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

info "⬤ Setting up Redis Sentinel (1 per VPS)"

# -------------------------------
# ASK SENTINEL PORT
# -------------------------------
SENTINEL_PORT=$(ask "Enter sentinel port (default 26379):")
[[ -z "$SENTINEL_PORT" ]] && SENTINEL_PORT=26379

# -------------------------------
# ASK SENTINEL PASSWORD
# -------------------------------
SENTINEL_PASSWORD=$(ask "Enter Sentinel password (required):")

if [[ -z "$SENTINEL_PASSWORD" ]]; then
  error "❌ Sentinel password cannot be empty"
  exit 1
fi

###############################################
# Detect NetBird Private IP (10.50.x.x)
###############################################
LOCAL_IP=$(hostname -I | tr ' ' '\n' | grep '^10\.50\.' | head -n1)

export LOCAL_IP

if [[ -z "$LOCAL_IP" ]]; then
  error "❌ Could not detect NetBird IP (10.50.x.x)."
  exit 1
fi



DATA_DIR="/opt/redis-sentinel/data-${SENTINEL_PORT}"
CONF_FILE="${DATA_DIR}/sentinel.conf"

safe_mkdir "$DATA_DIR"
# -------------------------------
# BASE TEMPLATE
# -------------------------------

env SENTINEL_PORT="$SENTINEL_PORT" \
    SENTINEL_PASSWORD="$SENTINEL_PASSWORD" \
    LOCAL_IP="$LOCAL_IP" \
    envsubst < "$TEMPLATE_DIR/sentinel.conf.tpl" > "$CONF_FILE"

info ""
info "🛰  Scanning Redis clusters under /opt/redis-stack-* ..."
info ""


# -------------------------------
# SCAN REDIS INSTANCES
# -------------------------------
for INSTANCE_DIR in /opt/redis-stack-*; do
  [[ ! -d "$INSTANCE_DIR" ]] && continue

  ENV_FILE="$INSTANCE_DIR/.env"
  [[ ! -f "$ENV_FILE" ]] && continue

  PORT=$(grep HOST_PORT= "$ENV_FILE" | cut -d'=' -f2)
  PASS=$(grep REDIS_PASSWORD= "$ENV_FILE" | cut -d'=' -f2)
  ROLE=$(grep ROLE= "$ENV_FILE" | cut -d'=' -f2)
  MASTER_IP=$(grep MASTER_IP= "$ENV_FILE" | cut -d'=' -f2)
  MASTER_PORT=$(grep MASTER_PORT= "$ENV_FILE" | cut -d'=' -f2)

  ###############################################
  # Ensure MASTER_IP is also NetBird private IP
  ###############################################
  if [[ "$ROLE" == "replica" ]]; then
    if [[ "$MASTER_IP" != 10.50.* ]]; then
      # Fetch NetBird IP from master node
      MASTER_IP=$(ssh root@"$MASTER_IP" "hostname -I | tr ' ' '\n' | grep '^10\.50\.' | head -n1")
    fi
  fi

  ###############################################
  # Determine TARGET master for monitoring
  ###############################################
  if [[ "$ROLE" == "master" ]]; then
      TARGET_IP="$LOCAL_IP"       # master on this VPS
      TARGET_PORT="$PORT"
  else
      TARGET_IP="$MASTER_IP"      # master on remote VPS (NetBird)
      TARGET_PORT="$MASTER_PORT"
  fi

  info "→ Registering cluster redis-${PORT}  MASTER = ${TARGET_IP}:${TARGET_PORT}"

  cat >> "$CONF_FILE" <<EOF

# ---- CLUSTER $PORT ----
sentinel monitor redis-${PORT} ${TARGET_IP} ${TARGET_PORT} 3
sentinel auth-pass redis-${PORT} ${PASS}
sentinel down-after-milliseconds redis-${PORT} 50000
sentinel failover-timeout redis-${PORT} 300000
sentinel parallel-syncs redis-${PORT} 1

EOF

done

info "✔ Sentinel config generated successfully at: $CONF_FILE"

# -------------------------------
# START CONTAINER
# -------------------------------
TMP_ENV="/tmp/sentinel-${SENTINEL_PORT}.env"
echo "SENTINEL_PORT=$SENTINEL_PORT" > "$TMP_ENV"
info "▶ Starting Sentinel Docker container..."

docker compose \
  -f "$TEMPLATE_DIR/sentinel-docker-compose.yml" \
  --env-file "$TMP_ENV" \
  -p "sentinel-${SENTINEL_PORT}" \
  up -d

success "🚀 Redis Sentinel started on port $SENTINEL_PORT"
success "✔ Monitoring ALL Redis clusters on this VPS"
