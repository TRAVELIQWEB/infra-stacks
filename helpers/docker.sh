#!/usr/bin/env bash

# Determine location of helpers
HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HELPER_DIR/io.sh"

install_docker() {
  info "Docker is not installed. Installing Docker Engine..."

  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh

  # Add current user to docker group
  if ! groups $USER | grep -q docker; then
    info "Adding user '$USER' to docker group..."
    sudo usermod -aG docker $USER
  fi

  # Enable and start docker service
  sudo systemctl enable docker
  sudo systemctl restart docker

  success "Docker installed successfully!"
}

install_docker_compose() {
  info "Docker Compose v2 not detected. Installing Compose plugin..."

  # Docker Compose v2 comes bundled with docker-ce via get-docker.sh
  # But if missing, install manually
  if ! docker compose version &>/dev/null; then
    sudo mkdir -p /usr/libexec/docker/cli-plugins

    LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
      | grep tag_name | cut -d '"' -f 4)

    sudo curl -SL \
      https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m) \
      -o /usr/libexec/docker/cli-plugins/docker-compose

    sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
  fi

  success "Docker Compose v2 installed successfully!"
}

check_docker() {
  if ! command -v docker &> /dev/null; then
    install_docker
  fi
}

check_docker_compose() {
  if ! docker compose version &> /dev/null; then
    install_docker_compose
  fi
}

docker_checks() {
  check_docker
  check_docker_compose
  success "Docker and Docker Compose are available."
}
