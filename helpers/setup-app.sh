#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"

info "🚀 Universal App Installer (Frontend / Backend)"

###############################################
# ASK FOR INPUTS
###############################################
APP_NAME=$(ask "Enter app name (example: wallet-frontend, air-api):")
ENVIRONMENT=$(ask "Enter environment (dev/staging/prod):")
SERVER_FOLDER=$(ask "Enter server folder path (example: /opt/apps OR /var/www/apps):")

###############################################
# SAFE DEFAULT SERVER PATH IF BLANK
###############################################
if [[ -z "$SERVER_FOLDER" ]]; then
  SERVER_FOLDER="/opt/apps"
fi

APP_ROOT="$SERVER_FOLDER/$ENVIRONMENT/$APP_NAME"
SECRET_FILE="$SERVER_FOLDER/$ENVIRONMENT/secrets/${APP_NAME}.env"

info "Setting up application at: $APP_ROOT"

###############################################
# 1. ENSURE DOCKER + COMPOSE INSTALLED
###############################################
docker_checks

###############################################
# 2. CREATE GLOBAL NETWORK (shared across apps)
###############################################
if ! docker network ls | grep -q "saarthi-net"; then
  info "Creating global Docker network 'saarthi-net'"
  docker network create saarthi-net
else
  info "Docker network 'saarthi-net' already exists"
fi

###############################################
# 3. CREATE FOLDERS
###############################################
info "Creating directories..."

mkdir -p "$SERVER_FOLDER/$ENVIRONMENT"
mkdir -p "$(dirname "$SECRET_FILE")"
mkdir -p "$APP_ROOT"

###############################################
# 4. CREATE SECRETS FILE IF NOT EXISTS
###############################################
if [[ ! -f "$SECRET_FILE" ]]; then
  info "Creating secrets file: $SECRET_FILE"
  echo "# Add your environment variables here" > "$SECRET_FILE"
else
  info "Using existing secrets file: $SECRET_FILE"
fi

###############################################
# 5. GENERATE DOCKER-COMPOSE TEMPLATE
###############################################
info "Generating docker-compose.yml"

cat > "$APP_ROOT/docker-compose.yml" <<EOF
version: "3.9"

services:
  ${APP_NAME}:
    container_name: ${APP_NAME}-${ENVIRONMENT}
    image: ghcr.io/TRAVELIQWEB/${APP_NAME}:${ENVIRONMENT}
    restart: always
    env_file:
      - $SECRET_FILE
    ports:
      - "0:3000"   # CHANGE THIS PORT AS NEEDED
    networks:
      - saarthi-net

networks:
  saarthi-net:
    external: true
EOF

###############################################
# 6. GENERATE DEPLOY SCRIPT
###############################################
info "Generating deploy.sh"

cat > "$APP_ROOT/deploy.sh" <<EOF
#!/usr/bin/env bash
set -e

echo "🚀 Deploying ${APP_NAME} (${ENVIRONMENT})"

cd \$(dirname "\$0")

docker pull ghcr.io/TRAVELIQWEB/${APP_NAME}:${ENVIRONMENT}

docker compose down
docker compose up -d

echo "✅ Deployment completed for ${APP_NAME} (${ENVIRONMENT})"
EOF

chmod +x "$APP_ROOT/deploy.sh"

###############################################
# 7. DONE
###############################################
success "Application setup complete!"

echo ""
echo "📌 App root folder: $APP_ROOT"
echo "📌 Secrets file: $SECRET_FILE"
echo "📌 Deployment: $APP_ROOT/deploy.sh"
echo "👉 Update docker-compose.yml to set correct port (6010:3000 etc.)"
