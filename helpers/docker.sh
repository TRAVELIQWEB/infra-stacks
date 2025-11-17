#!/usr/bin/env bash

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HELPER_DIR/io.sh"

#############################################
# AUTO INSTALL DOCKER
#############################################
install_docker() {
  info "Docker not found. Installing Docker Engine..."

  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh

  info "Adding user '$USER' to docker group..."
  sudo usermod -aG docker $USER

  sudo systemctl enable docker
  sudo systemctl restart docker

  success "Docker installed successfully!"
}

#############################################
# AUTO INSTALL DOCKER COMPOSE v2
#############################################
install_docker_compose() {
  info "Installing Docker Compose v2 plugin..."

  sudo mkdir -p /usr/libexec/docker/cli-plugins

  LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
    | grep tag_name | cut -d '"' -f 4)

  sudo curl -SL \
    https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m) \
    -o /usr/libexec/docker/cli-plugins/docker-compose

  sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

  success "Docker Compose v2 installed successfully!"
}

#############################################
# CHECK DOCKER INSTALLED → INSTALL IF MISSING
#############################################
check_docker() {
  if ! command -v docker &>/dev/null; then
    install_docker
  fi
}

#############################################
# CHECK DOCKER COMPOSE INSTALLED → INSTALL
#############################################
check_docker_compose() {
  if ! docker compose version &>/dev/null; then
    install_docker_compose
  fi
}

#############################################
# MAIN CHECK LOGIC
#############################################
docker_checks() {
  check_docker
  check_docker_compose

  # Permission check
  if ! docker ps &>/dev/null; then
    error "User '$USER' not in docker group."
    echo "Run:"
    echo "  sudo usermod -aG docker $USER"
    echo "  sudo reboot"
    exit 1
  fi

  success "Docker + Compose OK!"
}
