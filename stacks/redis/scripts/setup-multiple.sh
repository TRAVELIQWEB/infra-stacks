#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "Setting up multiple Redis Stack instances"

COUNT=$(ask "How many Redis instances? (e.g., 6):")
BASE_PORT=$(ask "Enter starting port (e.g., 6380):")
ROLE=$(ask "Are all instances master or replica? (master/replica):")

if [[ "$ROLE" != "master" && "$ROLE" != "replica" ]]; then
  error "Invalid role!"
  exit 1
fi

if [[ "$ROLE" == "replica" ]]; then
  MASTER_IP=$(ask "Enter master IP:")
  MASTER_PORT=$(ask "Enter master Redis port:")
fi

echo ""
info "🚀 Creating $COUNT Redis instances, starting from port $BASE_PORT"
echo ""

for ((i=0; i<COUNT; i++)); do
  PORT=$((BASE_PORT + i))

  echo ""
  info "➡ Instance $((i+1)) on port $PORT"

  export PORT ROLE MASTER_IP MASTER_PORT

  bash "$BASE_DIR/stacks/redis/scripts/setup-instance.sh"
done

echo ""
success "🎉 All Redis instances created successfully!"
