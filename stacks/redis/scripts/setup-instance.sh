#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "Setting up a Redis Stack instance"

###############################################
# 1. PORT (skip if passed by multiple script)
###############################################
if [[ -z "$PORT" ]]; then
  PORT=$(ask "Enter Redis port to expose:")
fi

###############################################
# 2. ROLE (skip if provided externally)
###############################################
if [[ -z "$ROLE" ]]; then
  ROLE=$(ask "Is this instance master or replica? (master/replica):")
fi

if [[ "$ROLE" != "master" && "$ROLE" != "replica" ]]; then
  error "Invalid role! Choose master/replica"
  exit 1
fi

###############################################
# 3. MASTER INFO for replicas
###############################################
if [[ "$ROLE" == "replica" ]]; then
  [[ -z "$MASTER_IP" ]] && MASTER_IP=$(ask "Enter master IP:")
  [[ -z "$MASTER_PORT" ]] && MASTER_PORT=$(ask "Enter master Redis port:")
fi

###############################################
# 4. PASSWORD
###############################################
PASS_INPUT=$(ask "Enter password for Redis $PORT (blank = auto-generate):")

if [[ -z "$PASS_INPUT" ]]; then
  REDIS_PASSWORD=$(generate_password)
  info "Generated password for $PORT: $REDIS_PASSWORD"
else
  REDIS_PASSWORD="$PASS_INPUT"
fi


###############################################
# 5. Directory setup
###############################################
INSTANCE_DIR="/opt/redis-stack-${PORT}"
DATA_DIR="${INSTANCE_DIR}/data"
CONF_DIR="${INSTANCE_DIR}/conf"
ENV_FILE="${INSTANCE_DIR}/.env"
CONF_FILE="${CONF_DIR}/redis-${PORT}.conf"

if docker ps -a --format '{{.Names}}' | grep -q "^redis-stack-${PORT}$"; then
  error "Redis instance redis-stack-${PORT} already exists!"
  exit 1
fi

safe_mkdir "$INSTANCE_DIR"
safe_mkdir "$DATA_DIR"
safe_mkdir "$CONF_DIR"

###############################################
# 6. Environment file
###############################################
HOST_PORT_UI=$((PORT + 10000))

cat > "$ENV_FILE" <<EOF
CONTAINER_NAME=redis-stack-${PORT}
HOST_PORT=${PORT}
HOST_PORT_UI=${HOST_PORT_UI}
DATA_DIR=${DATA_DIR}
CONF_FILE=${CONF_FILE}
REDIS_PASSWORD=${REDIS_PASSWORD}
MASTER_IP=${MASTER_IP}
MASTER_PORT=${MASTER_PORT}
ROLE=${ROLE}
EOF

###############################################
# 7. PUBLIC IP (needed for replica announce)
###############################################
# PUBLIC_IP=$(curl -s ifconfig.me)
# export PUBLIC_IP

###############################################
# 8. Generate redis.conf
###############################################
# export HOST_PORT="$PORT"
# export REDIS_PASSWORD MASTER_IP MASTER_PORT ROLE PUBLIC_IP

export HOST_PORT="$PORT"
export REDIS_PASSWORD MASTER_IP MASTER_PORT ROLE


envsubst < "$BASE_DIR/stacks/redis/templates/redis.conf.tpl" > "$CONF_FILE"

if [[ "$ROLE" == "replica" ]]; then
  echo "replicaof ${MASTER_IP} ${MASTER_PORT}" >> "$CONF_FILE"
fi

###############################################
# 9. Start container
###############################################
info "Starting Redis Stack container on port $PORT..."

docker compose \
  -f "$BASE_DIR/stacks/redis/templates/docker-compose.yml" \
  --env-file "$ENV_FILE" \
  -p "redis-stack-${PORT}" \
  up -d

success "Redis Stack $PORT created!"

echo ""
echo "🔹 Redis:       localhost:${PORT}"
echo "🔹 Redis UI:    http://localhost:${HOST_PORT_UI}"
echo "🔹 Role:        $ROLE"
echo "🔹 Password:    $REDIS_PASSWORD"
if [[ "$ROLE" == "replica" ]]; then
  echo "🔹 Master:      $MASTER_IP:$MASTER_PORT"
fi
