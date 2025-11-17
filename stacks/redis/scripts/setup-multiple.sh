#!/usr/bin/env bash
set -e

BASE_DIR="$(dirname "$(dirname "$(dirname "$0")")")"
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

MASTER_IP=""
if [[ "$ROLE" == "replica" ]]; then
  MASTER_IP=$(ask "Enter master IP:")
fi

for ((i=0; i<COUNT; i++)); do
  PORT=$((BASE_PORT + i))

  info "➡ Creating Redis instance on port $PORT"

  bash "$BASE_DIR/stacks/redis/scripts/setup-instance.sh"
done

success "All Redis instances created successfully!"
