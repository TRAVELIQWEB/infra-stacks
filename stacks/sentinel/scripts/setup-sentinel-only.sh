#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "🔵 Setting up Sentinel-only VPS (NO Redis servers on this VPS)"

###############################################
# 1) Sentinel Port
###############################################
SENTINEL_PORT=$(ask "Enter Sentinel port (default 26379):")
[[ -z "$SENTINEL_PORT" ]] && SENTINEL_PORT=26379


###############################################
# 2) Master Node Info (VPS1)
###############################################
MASTER_IP=$(ask "Enter MASTER IP of VPS1 (e.g., 154.210.206.44):")
REDIS_PASSWORD=$(ask "Enter Redis password for all clusters:")


###############################################
# 3) Redis Cluster Range
###############################################
COUNT=$(ask "How many Redis ports/clusters? (e.g., 6):")
START_PORT=$(ask "Enter starting Redis port (e.g., 6379 OR 6380):")

echo ""
info "➡ Sentinel will monitor $COUNT clusters starting from port $START_PORT"
echo ""


###############################################
# 4) Create sentinel configuration directory
###############################################
CONF_DIR="/opt/redis-sentinel"
CONF_FILE="${CONF_DIR}/sentinel-${SENTINEL_PORT}.conf"

safe_mkdir "$CONF_DIR"
echo "" > "$CONF_FILE"


###############################################
# 5) Generate Sentinel Config
###############################################
for ((i=0; i<COUNT; i++)); do
  PORT=$((START_PORT + i))

  {
    echo "sentinel monitor redis-${PORT} ${MASTER_IP} ${PORT} 2"
    echo "sentinel auth-pass redis-${PORT} ${REDIS_PASSWORD}"
    echo "sentinel down-after-milliseconds redis-${PORT} 5000"
    echo "sentinel failover-timeout redis-${PORT} 180000"
    echo "sentinel parallel-syncs redis-${PORT} 1"
    echo ""
  } >> "$CONF_FILE"

done

success "✔ Generated Sentinel config: $CONF_FILE"


###############################################
# 6) EXPORT variables so docker-compose can use them
###############################################
export SENTINEL_PORT CONF_FILE


###############################################
# 7) Start sentinel container
###############################################
docker compose \
  -f "$BASE_DIR/stacks/sentinel/templates/sentinel-docker-compose.yml" \
  -p "sentinel-${SENTINEL_PORT}" \
  up -d

success "🚀 Sentinel-only node started successfully!"
echo ""
info "✔ Monitoring ${COUNT} Redis clusters"
info "✔ Using MASTER IP: ${MASTER_IP}"
info "✔ Sentinel running on port ${SENTINEL_PORT}"
