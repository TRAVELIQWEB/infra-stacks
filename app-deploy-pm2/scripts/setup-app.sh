#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$BASE_DIR/templates"

echo "🚀 PM2 App Setup Tool"

###############################################
# ASK USER INPUTS
###############################################

read -p "Enter app name (example: wallet-frontend): " APP_NAME
read -p "Enter environment (dev/staging/prod): " ENV
read -p "Enter domain PM2 name (example: air.saarthii.co.in): " PM2_NAME
read -p "Enter port: " PORT

echo "Select app type:"
echo "1) Next.js (frontend)"
echo "2) NestJS (backend)"
read -p "Enter choice (1 or 2): " APP_TYPE

###############################################
# PATHS
###############################################

ROOT_PATH="/var/www/apps/$ENV/$APP_NAME"
ENV_FILE="$ROOT_PATH/.env"
DEPLOY_FILE="$ROOT_PATH/deploy.sh"
ROLLBACK_FILE="$ROOT_PATH/rollback.sh"

mkdir -p "$ROOT_PATH"

###############################################
# COPY ENV TEMPLATE
###############################################
cp "$TEMPLATE_DIR/env.template" "$ENV_FILE"
echo "PORT=$PORT" >> "$ENV_FILE"

###############################################
# SELECT DEPLOY TEMPLATE
###############################################

if [[ "$APP_TYPE" == "1" ]]; then
  DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-next.sh.template"
  echo "App Type: Next.js"
else
  DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-nest.sh.template"
  echo "App Type: NestJS"
fi

###############################################
# GENERATE deploy.sh
###############################################
sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__PM2_NAME__|$PM2_NAME|g" \
  -e "s|__PORT__|$PORT|g" \
  -e "s|__ENV__|$ENV|g" \
  "$DEPLOY_TEMPLATE" > "$DEPLOY_FILE"

chmod +x "$DEPLOY_FILE"

###############################################
# GENERATE rollback.sh
###############################################
sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__ENV__|$ENV|g" \
  "$TEMPLATE_DIR/rollback.sh.template" > "$ROLLBACK_FILE"

chmod +x "$ROLLBACK_FILE"

###############################################
echo "🎉 App setup completed!"
echo "📁 App root: $ROOT_PATH"
echo "📝 Env file: $ENV_FILE"
echo "🚀 Deploy using:"
echo "     $DEPLOY_FILE"
echo "↩ Rollback using:"
echo "     $ROLLBACK_FILE"
echo "🔥 PM2 Name: $PM2_NAME"
