#!/usr/bin/env bash

# Determine the directory where this file is located
HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

source "$HELPER_DIR/io.sh"

check_docker() {
  if ! command -v docker &> /dev/null; then
    error "Docker is not installed!"
    exit 1
  fi
}

check_docker_compose() {
  if ! docker compose version &> /dev/null; then
    error "Docker Compose v2 is not installed!"
    exit 1
  fi
}

docker_checks() {
  check_docker
  check_docker_compose
  success "Docker and Docker Compose are available."
}
