#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# Paths
# ---------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_DIR="$(cd "$STACK_DIR/../.." && pwd)"
TEMPLATE_DIR="$STACK_DIR/templates"

# ---------------------------------------------
# Helpers (KEEP)
# ---------------------------------------------
# shellcheck source=/dev/null
source "$BASE_DIR/helpers/io.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/helpers/docker.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/helpers/utils.sh"

docker_checks

# ---------------------------------------------
# Basic requirements (defensive)
# ---------------------------------------------
if ! command -v envsubst >/dev/null 2>&1; then
  error "❌ 'envsubst' not found. Install it: sudo apt-get update && sudo apt-get install -y gettext-base"
  exit 1
fi

if [[ ! -f "$TEMPLATE_DIR/sentinel.conf.tpl" ]]; then
  error "❌ Missing template: $TEMPLATE_DIR/sentinel.conf.tpl"
  exit 1
fi

if [[ ! -f "$TEMPLATE_DIR/sentinel-docker-compose.yml" ]]; then
  error "❌ Missing compose file: $TEMPLATE_DIR/sentinel-docker-compose.yml"
  exit 1
fi

info "⬤ Setting up Redis Sentinel (1 per VPS)"

# ---------------------------------------------
# Sentinel port
# ---------------------------------------------
SENTINEL_PORT="${SENTINEL_PORT:-}"
if [[ -z "${SENTINEL_PORT}" ]]; then
  SENTINEL_PORT="$(ask "Enter sentinel port (default 26379):")"
fi
[[ -z "${SENTINEL_PORT}" ]] && SENTINEL_PORT="26379"

if [[ ! "${SENTINEL_PORT}" =~ ^[0-9]+$ ]]; then
  error "❌ Sentinel port must be numeric. Got: ${SENTINEL_PORT}"
  exit 1
fi

# ---------------------------------------------
# Sentinel password
# ---------------------------------------------
SENTINEL_PASSWORD="${SENTINEL_PASSWORD:-}"
if [[ -z "${SENTINEL_PASSWORD}" ]]; then
  SENTINEL_PASSWORD="$(ask "Enter Sentinel password (required):")"
fi
if [[ -z "${SENTINEL_PASSWORD}" ]]; then
  error "❌ Sentinel password cannot be empty"
  exit 1
fi

# ---------------------------------------------
# Detect NetBird private IP (10.50.x.x)
# ---------------------------------------------
LOCAL_IP="$(hostname -I | tr ' ' '\n' | grep '^10\.50\.' | head -n1 || true)"
if [[ -z "$LOCAL_IP" ]]; then
  error "❌ Could not detect NetBird IP (10.50.x.x). Set it manually: export LOCAL_IP=10.50.x.x"
  exit 1
fi
export LOCAL_IP

# ---------------------------------------------
# Static master map (masters.env)
# ---------------------------------------------
MASTER_MAP="/opt/redis-sentinel/masters.env"

if [[ ! -f "$MASTER_MAP" ]]; then
  if [[ "${ALLOW_MASTER_MAP_GENERATION:-no}" != "yes" ]]; then
    error "❌ masters.env missing at: $MASTER_MAP"
    error "👉 Generate it ONLY ON PRIMARY Redis VPS:"
    error "   export ALLOW_MASTER_MAP_GENERATION=yes"
    error "   bash setup-sentinel.sh"
    exit 1
  fi

  info "⚙️  masters.env not found — generating from local redis-stack-* (PRIMARY VPS only)"

  CONFIRM_MASTER_GEN="$(ask "⚠️ Are you on the PRIMARY MASTER Redis VPS? Type YES to continue:")"
  if [[ "$CONFIRM_MASTER_GEN" != "YES" ]]; then
    error "Cancelled. Do not generate masters.env on non-master VPS."
    exit 1
  fi

  safe_mkdir "/opt/redis-sentinel"
  : > "$MASTER_MAP"

  # Detect redis-stack directories and sort ports properly
  REDIS_DIRS="$(ls -d /opt/redis-stack-* 2>/dev/null | sort -V || true)"
  if [[ -z "$REDIS_DIRS" ]]; then
    error "❌ No redis-stack-* directories found. Redis must be set up first."
    exit 1
  fi

  for DIR in $REDIS_DIRS; do
    PORT="$(basename "$DIR" | sed 's/redis-stack-//')"
    if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
      continue
    fi

    ENV_FILE="$DIR/.env"
    if [[ ! -f "$ENV_FILE" ]]; then
      error "❌ Missing Redis env file: $ENV_FILE"
      exit 1
    fi

    PASS="$(grep '^REDIS_PASSWORD=' "$ENV_FILE" | head -n1 | cut -d'=' -f2- || true)"
    if [[ -z "$PASS" ]]; then
      error "❌ REDIS_PASSWORD missing in $ENV_FILE"
      exit 1
    fi

    # IMPORTANT: no leading spaces, and keep newline between entries
    cat >> "$MASTER_MAP" <<EOF
REDIS_${PORT}_MASTER_IP=${LOCAL_IP}
REDIS_${PORT}_MASTER_PASSWORD=${PASS}

EOF

    info "✔ Registered master redis-${PORT} at ${LOCAL_IP}:${PORT}"
  done

  chmod 600 "$MASTER_MAP"
  success "✅ masters.env generated at $MASTER_MAP"
else
  info "✔ Using existing masters.env: $MASTER_MAP"
fi

# Fix CRLF if copied from Windows
sudo sed -i 's/\r$//' "$MASTER_MAP" 2>/dev/null || true

# shellcheck source=/dev/null
source "$MASTER_MAP"

# ---------------------------------------------
# Ports list (default 6380-6385)
# Override: export REDIS_PORTS="6380 6381 ..."
# ---------------------------------------------
REDIS_PORTS="${REDIS_PORTS:-6380 6381 6382 6383 6384 6385}"

for p in $REDIS_PORTS; do
  if [[ ! "$p" =~ ^[0-9]+$ ]]; then
    error "❌ Invalid port in REDIS_PORTS: '$p' (must be numeric)"
    exit 1
  fi
done

# ---------------------------------------------
# Prepare directories
# ---------------------------------------------
DATA_DIR="/opt/redis-sentinel/data-${SENTINEL_PORT}"
CONF_FILE="${DATA_DIR}/sentinel.conf"
TMP_CONF="${DATA_DIR}/sentinel.conf.tmp"

safe_mkdir "$DATA_DIR"

# ---------------------------------------------
# Write base config
# ---------------------------------------------
env SENTINEL_PORT="$SENTINEL_PORT" \
  SENTINEL_PASSWORD="$SENTINEL_PASSWORD" \
  LOCAL_IP="$LOCAL_IP" \
  envsubst < "$TEMPLATE_DIR/sentinel.conf.tpl" > "$TMP_CONF"

info ""
info "🛰  Registering Redis clusters using masters.env"
info ""

# ---------------------------------------------
# Append clusters
# ---------------------------------------------
for PORT in $REDIS_PORTS; do
  MASTER_VAR="REDIS_${PORT}_MASTER_IP"
  MASTER_IP="${!MASTER_VAR:-}"
  if [[ -z "$MASTER_IP" ]]; then
    error "❌ masters.env missing: ${MASTER_VAR}=<ip>"
    exit 1
  fi

  PASS_VAR="REDIS_${PORT}_MASTER_PASSWORD"
  PASS="${!PASS_VAR:-}"
  if [[ -z "$PASS" ]]; then
    error "❌ masters.env missing: ${PASS_VAR}=<password>"
    exit 1
  fi

  info "→ redis-${PORT} MASTER = ${MASTER_IP}:${PORT}"

  cat >> "$TMP_CONF" <<EOF

# ---- CLUSTER ${PORT} ----
sentinel monitor redis-${PORT} ${MASTER_IP} ${PORT} 2
sentinel auth-pass redis-${PORT} ${PASS}
sentinel down-after-milliseconds redis-${PORT} 15000
sentinel failover-timeout redis-${PORT} 90000
sentinel parallel-syncs redis-${PORT} 1
EOF
done

# Atomic replace
mv -f "$TMP_CONF" "$CONF_FILE"
chmod 600 "$CONF_FILE" || true

info "✔ Sentinel config generated at: $CONF_FILE"

# ---------------------------------------------
# Start/Restart Sentinel container
# ---------------------------------------------
TMP_ENV="/tmp/sentinel-${SENTINEL_PORT}.env"
echo "SENTINEL_PORT=$SENTINEL_PORT" > "$TMP_ENV"

PROJECT_NAME="sentinel-${SENTINEL_PORT}"

info "▶ Starting Redis Sentinel container (project: $PROJECT_NAME)..."

docker compose \
  -f "$TEMPLATE_DIR/sentinel-docker-compose.yml" \
  --env-file "$TMP_ENV" \
  -p "$PROJECT_NAME" \
  up -d --force-recreate

success "🚀 Redis Sentinel started on port $SENTINEL_PORT"
success "✔ Monitoring Redis clusters (masters.env; stable quorum)"
