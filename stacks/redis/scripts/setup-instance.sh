#!/usr/bin/env bash
set -e

BASE_DIR="$(dirname "$(dirname "$(dirname "$0")")")"
source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "Setting up a Redis Stack instance"

# Ask required inputs
PORT=$(ask "Enter Redis port to expose (e.g., 6380):")
ROLE=$(ask "Is this instance master or replica? (master/replica):")

if [[ "$ROLE" != "master" && "$ROLE" != "replica" ]]; then
  error "Invalid role! Choose 'master' or 'replica'"
  exit 1
fi

# Check if already exists
if docker ps -a --format '{{.Names}}' | grep -q "^redis-stack-${PORT}$"; then
  error "Redis instance redis-stack-${PORT} already exists!"
  exit 1
fi

PASS_INPUT=$(ask "Enter Redis password (leave empty for auto-generate):")
if [[ -z "$PASS_INPUT" ]]; then
  REDIS_PASSWORD=$(generate_password)
  info "Generated password: $REDIS_PASSWORD"
else
  REDIS_PASSWORD="$PASS_INPUT"
fi

MASTER_IP=""
MASTER_PORT=""

if [[ "$ROLE" == "replica" ]]; then
  MASTER_IP=$(ask "Enter master IP:")
  MASTER_PORT="$PORT"
fi

INSTANCE_DIR="/opt/redis-stack-${PORT}"
DATA_DIR="${INSTANCE_DIR}/data"
CONF_DIR="${INSTANCE_DIR}/conf"
CONF_FILE="${CONF_DIR}/redis-${PORT}.conf"
ENV_FILE="${INSTANCE_DIR}/.env"

safe_mkdir "$INSTANCE_DIR"
safe_mkdir "$DATA_DIR"
safe_mkdir "$CONF_DIR"

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

envsubst < "$BASE_DIR/stacks/redis/templates/redis.conf.tpl" > "$CONF_FILE"

if [[ "$ROLE" == "replica" ]]; then
  echo "replicaof ${MASTER_IP} ${MASTER_PORT}" >> "$CONF_FILE"
fi

info "Starting Redis Stack container..."
docker compose \
  -f "$BASE_DIR/stacks/redis/templates/docker-compose.yml" \
  --env-file "$ENV_FILE" \
  -p "redis-stack-${PORT}" \
  up -d

success "Redis Stack instance created!"
echo ""
echo "🔹 Redis:       localhost:${PORT}"
echo "🔹 Redis UI:    http://localhost:${HOST_PORT_UI}"
echo "🔹 Role:        $ROLE"
echo "🔹 Password:    $REDIS_PASSWORD"
if [[ "$ROLE" == "replica" ]]; then
  echo "🔹 Master:      $MASTER_IP:$MASTER_PORT"
fi
