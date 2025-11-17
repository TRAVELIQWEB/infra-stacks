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

info "Setting up multiple Redis Stack instances"

COUNT=$(ask "How many Redis instances? (e.g., 6):")
START_PORT=$(ask "Enter starting port (e.g., 6380):")
ROLE=$(ask "Are all instances master or replica? (master/replica):")

MASTER_IP=""
MASTER_PORT=""

if [[ "$ROLE" == "replica" ]]; then
  MASTER_IP=$(ask "Enter master IP:")
fi

info "🚀 Creating $COUNT Redis instances, starting from port $START_PORT"
echo ""

for ((i=0; i<COUNT; i++)); do
  PORT=$((START_PORT + i))
  UI_PORT=$((16380 + i))

  info "➡ Instance $((i+1)) of $COUNT on port $PORT"

  docker_checks

  PASSWORD=$(ask "Enter password for Redis $PORT (blank = auto-generate):")

  if [[ -z "$PASSWORD" ]]; then
    PASSWORD=$(openssl rand -base64 18)
  fi

  # Asking master port per instance (OPTION 2)
  if [[ "$ROLE" == "replica" ]]; then
    MASTER_PORT=$(ask "Enter master Redis port for instance $PORT:")
  fi

  INSTANCE_DIR="/opt/redis-stack-$PORT"
  safe_mkdir "$INSTANCE_DIR/conf"
  safe_mkdir "$INSTANCE_DIR/data"

  # Create .env
  cat > "$INSTANCE_DIR/.env" <<EOF
HOST_PORT=$PORT
UI_PORT=$UI_PORT
REDIS_PASSWORD=$PASSWORD
ROLE=$ROLE
MASTER_IP=$MASTER_IP
MASTER_PORT=$MASTER_PORT
EOF

  info "Starting Redis Stack container on port $PORT..."
  docker compose -f "$TEMPLATE_DIR/docker-compose.yml" --env-file "$INSTANCE_DIR/.env" up -d

  success "Redis Stack $PORT created!"
  echo ""
  echo "🔹 Redis:       localhost:$PORT"
  echo "🔹 Redis UI:    http://localhost:$UI_PORT"
  echo "🔹 Role:        $ROLE"
  echo "🔹 Password:    $PASSWORD"
  if [[ "$ROLE" == "replica" ]]; then
    echo "🔹 Master:      $MASTER_IP:$MASTER_PORT"
  fi
  echo ""
done

success "🎉 All Redis instances created successfully!"
