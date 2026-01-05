  #!/usr/bin/env bash
  set -e

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  TEMPLATE_DIR="$BASE_DIR/templates"

  echo "🚀 PM2 App Setup Tool"

  ###############################################
  # 0) INSTALL NODE 20 + NPM IF MISSING
  ###############################################
  if ! command -v node >/dev/null 2>&1; then
      echo "⚠️ Node.js not found. Installing Node.js 20 + npm..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt install -y nodejs
  else
      echo "✅ Node.js already installed: $(node -v)"
  fi

  ###############################################
  # 1) INSTALL PM2 IF MISSING
  ###############################################
  if ! command -v pm2 >/dev/null 2>&1; then
      echo "⚠️ PM2 not found. Installing globally..."
      sudo npm install -g pm2@latest
  else
      echo "✅ PM2 already installed: $(pm2 -v)"
  fi

  ###############################################
  # 2) ASK USER INPUTS
  ###############################################
  read -p "Enter app name (example: wallet-frontend): " APP_NAME
  read -p "Enter environment (dev/staging/prod): " ENV
  read -p "Enter domain PM2 name (example: air.saarthii.co.in): " PM2_NAME
  read -p "Enter port: " PORT

  # Validate port
  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid port number! Must be digits only."
    exit 1
  fi

  echo "Select app type:"
  echo "1) Next.js (Nx Monorepo – build on server)"
  echo "2) Next.js (Standalone – build on server)"
  echo "3) NestJS (backend)"
  echo "4) Next.js (Standalone – Sync-based, LB safe)"
  echo "5) Next.js (Nx Monorepo – Sync-based, LB safe)"
  read -p "Enter choice (1/2/3/4/5): " APP_TYPE
  read -p "Enter repository (example: TRAVELIQWEB/wallet-api): " GIT_REPO


  GIT_REPO=$(echo "$GIT_REPO" | xargs)


  ###############################################
  # ASK FOR CPU CORES FOR PM2
  ###############################################
  read -p "Enter number of CPU cores to use (1 for single core, 'max' for all cores): " CPU_CORES

  # Auto-correct invalid input
  TOTAL_CORES=$(nproc)

  if [[ "$CPU_CORES" =~ ^[0-9]+$ ]]; then
      if (( CPU_CORES < 1 )); then
          CPU_CORES=1
      elif (( CPU_CORES > TOTAL_CORES )); then
          CPU_CORES=$TOTAL_CORES
      fi
  else
      CPU_CORES=1
  fi

  echo "✔ Using $CPU_CORES core(s) for PM2"


  ###############################################
  # 3) DEFINE PATHS (SAFE STRUCTURE)
  ###############################################
  ROOT_PATH="/var/www/apps/$ENV/$APP_NAME"

  SCRIPT_DIR_PATH="$ROOT_PATH/scripts"
  ENV_DIR_PATH="$ROOT_PATH/env"
  CURRENT_PATH="$ROOT_PATH/current"
  BACKUP_PATH="$ROOT_PATH/backup"
  RELEASES_PATH="$ROOT_PATH/releases"

  ENV_FILE="$ENV_DIR_PATH/.env"
  DEPLOY_FILE="$SCRIPT_DIR_PATH/deploy.sh"
  ROLLBACK_FILE="$SCRIPT_DIR_PATH/rollback.sh"




  # Create folders
  sudo mkdir -p "$SCRIPT_DIR_PATH" "$ENV_DIR_PATH" "$CURRENT_PATH" "$BACKUP_PATH" "$RELEASES_PATH"


  # Give ownership back to the current user
  sudo chown -R $USER:$USER "$ROOT_PATH"

  # Ensure folders are tracked in Git
  touch "$SCRIPT_DIR_PATH/.gitkeep"
  touch "$ENV_DIR_PATH/.gitkeep"
  touch "$CURRENT_PATH/.gitkeep"
  touch "$BACKUP_PATH/.gitkeep"
  touch "$RELEASES_PATH/.gitkeep"

  ###############################################
  # 4) COPY ENV TEMPLATE
  ###############################################
  cp "$TEMPLATE_DIR/env.template" "$ENV_FILE"
  echo "PORT=$PORT" >> "$ENV_FILE"

  ###############################################
  # 4.1) ASK FOR SYNC HOSTS (ONLY FOR SYNC APPS)
  ###############################################
  if [[ "$APP_TYPE" == "4" || "$APP_TYPE" == "5" ]]; then
    read -p "Enter sync hosts (space separated, e.g. frontend3 frontend4): " SYNC_HOSTS

    if [ -n "$SYNC_HOSTS" ]; then
      echo "SYNC_HOSTS=\"$SYNC_HOSTS\"" >> "$ENV_FILE"
      echo "✔ Sync hosts set: $SYNC_HOSTS"
    else
      echo "⚠ No sync hosts provided, sync will be skipped"
    fi
  fi


  ###############################################
  # 5) SELECT DEPLOY TEMPLATE
  ###############################################
  case "$APP_TYPE" in
    1)
      DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-next-nx.sh.template"
      APP_TYPE_LABEL="Next.js (Nx Monorepo – build on server)"
      ;;
    2)
      DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-next-standalone.sh.template"
      APP_TYPE_LABEL="Next.js (Standalone – build on server)"
      ;;
    3)
      DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-nest.sh.template"
      APP_TYPE_LABEL="NestJS (backend)"
      ;;
    4)
      DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-nextjs-standalone-sync.sh.template"
      APP_TYPE_LABEL="Next.js (Standalone – Sync-based, LB safe)"
      ;;
    5)
      DEPLOY_TEMPLATE="$TEMPLATE_DIR/deploy-nextjs-nx-sync.sh.template"
      APP_TYPE_LABEL="Next.js (Nx Monorepo – Sync-based, LB safe)"
      ;;
    *)
      echo "❌ Invalid app type selected."
      exit 1
      ;;
  esac


  echo "App Type: $APP_TYPE_LABEL"

  ###############################################
  # 6) GENERATE deploy.sh
  ###############################################
  sed \
    -e "s|__APP_NAME__|$APP_NAME|g" \
    -e "s|__PM2_NAME__|$PM2_NAME|g" \
    -e "s|__PORT__|$PORT|g" \
    -e "s|__ENV__|$ENV|g" \
    -e "s|__GIT_REPO__|$GIT_REPO|g" \
    -e "s|__CPU_CORES__|$CPU_CORES|g" \
    "$DEPLOY_TEMPLATE" > "$DEPLOY_FILE"

  chmod +x "$DEPLOY_FILE"

  ###############################################
  # 7) GENERATE rollback.sh
  ###############################################
  sed \
    -e "s|__APP_NAME__|$APP_NAME|g" \
    -e "s|__ENV__|$ENV|g" \
    "$TEMPLATE_DIR/rollback.sh.template" > "$ROLLBACK_FILE"

  chmod +x "$ROLLBACK_FILE"

  ###############################################
  # 8) DONE
  ###############################################
  echo "🎉 App setup completed!"
  echo "📁 App root: $ROOT_PATH"
  echo "📝 Env file: $ENV_FILE"
  echo "🚀 Deploy using: $DEPLOY_FILE"
  echo "↩ Rollback using: $ROLLBACK_FILE"
  echo "🔥 PM2 Name: $PM2_NAME"
