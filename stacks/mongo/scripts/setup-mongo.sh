#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/docker.sh"
source "$BASE_DIR/helpers/utils.sh"

docker_checks

info "Setting up a MongoDB instance (Docker, replica set ready)"

###############################################
# 1. Ask for port
###############################################
MONGO_PORT=$(ask "Enter MongoDB port to expose (default 27017):")
[[ -z "$MONGO_PORT" ]] && MONGO_PORT=27017

###############################################
# 2. Role (for your reference)
###############################################
ROLE=$(ask "Is this instance master or replica? (master/replica) [default: master]:")
[[ -z "$ROLE" ]] && ROLE="master"

if [[ "$ROLE" != "master" && "$ROLE" != "replica" ]]; then
  error "Invalid role! Choose master/replica"
  exit 1
fi

###############################################
# 3. Replica set name
###############################################
REPLICA_SET=$(ask "Enter replica set name (e.g., rs0) [default: rs0]:")
[[ -z "$REPLICA_SET" ]] && REPLICA_SET="rs0"

###############################################
# 4. Root user credentials
###############################################
MONGO_ROOT_USERNAME=$(ask "Enter Mongo root username (default: root):")
[[ -z "$MONGO_ROOT_USERNAME" ]] && MONGO_ROOT_USERNAME="root"

PASS_INPUT=$(ask "Enter Mongo root password for port $MONGO_PORT (blank = auto-generate):")
if [[ -z "$PASS_INPUT" ]]; then
  MONGO_ROOT_PASSWORD=$(generate_password)
  info "Generated Mongo root password for $MONGO_PORT: $MONGO_ROOT_PASSWORD"
else
  MONGO_ROOT_PASSWORD="$PASS_INPUT"
fi

###############################################
# 5. KeyFile for internal authentication
#    Must be the SAME on ALL replica members.
#    On first server it will be created.
#    Copy /opt/mongo-keyfile/mongo-keyfile to
#    all other servers before running this script.
###############################################
KEY_DIR="/opt/mongo-keyfile/${REPLICA_SET}"
KEY_FILE="${KEY_DIR}/mongo-keyfile"

sudo mkdir -p "$KEY_DIR"

if [[ ! -f "$KEY_FILE" ]]; then
  info "No keyFile found at $KEY_FILE. Generating new keyFile (use this SAME file on all replica set members)."
  openssl rand -base64 756 | sudo tee "$KEY_FILE" >/dev/null
  sudo chmod 600 "$KEY_FILE"
else
  info "Reusing existing keyFile at $KEY_FILE"
fi

# Make sure mongod (uid 999) can read it
sudo chown 999:999 "$KEY_FILE" || true

###############################################
# 6. Instance directories
###############################################
INSTANCE_DIR="/opt/mongo-${MONGO_PORT}"
DATA_DIR="${INSTANCE_DIR}/data"
CONF_DIR="${INSTANCE_DIR}/conf"
ENV_FILE="${INSTANCE_DIR}/.env"
CONF_FILE="${CONF_DIR}/mongod-${MONGO_PORT}.conf"

if docker ps -a --format '{{.Names}}' | grep -q "^mongo-${MONGO_PORT}$"; then
  error "Mongo instance mongo-${MONGO_PORT} already exists!"
  exit 1
fi

safe_mkdir "$INSTANCE_DIR"
safe_mkdir "$DATA_DIR"
safe_mkdir "$CONF_DIR"

###############################################
# 7. Environment file for docker compose
###############################################
cat > "$ENV_FILE" <<EOF
CONTAINER_NAME=mongo-${MONGO_PORT}
MONGO_IMAGE=mongo:8
MONGO_PORT=${MONGO_PORT}
MONGO_ROOT_USERNAME=${MONGO_ROOT_USERNAME}
MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}
MONGO_REPLICA_SET=${REPLICA_SET}
MONGO_ROLE=${ROLE}
DB_PATH=${DATA_DIR}
CONFIG_FILE=${CONF_FILE}
KEYFILE_PATH=${KEY_FILE}
EOF

###############################################
# 8. Generate mongod.conf from template
###############################################
export MONGO_PORT
export MONGO_REPLICA_SET="${REPLICA_SET}"

envsubst < "$BASE_DIR/stacks/mongo/templates/mongod.conf.tpl" > "$CONF_FILE"

###############################################
# 9. Start MongoDB container
###############################################
info "Starting MongoDB container on port $MONGO_PORT..."

docker compose \
  -f "$BASE_DIR/stacks/mongo/templates/docker-compose.yml" \
  --env-file "$ENV_FILE" \
  -p "mongo-${MONGO_PORT}" \
  up -d

CONTAINER_NAME="mongo-${MONGO_PORT}"

###############################################
# 10. Wait for MongoDB to be ready
###############################################
info "Waiting for MongoDB to be ready..."
until docker exec "$CONTAINER_NAME" mongosh --host localhost --port 27017 --quiet --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; do
  sleep 2
done

success "MongoDB on port $MONGO_PORT is up."

###############################################
# 11. (Optional) Initiate replica set from master
###############################################
if [[ "$ROLE" == "master" ]]; then
  # Try to use NetBird IP first (10.50.x.x), else first IP
  LOCAL_IP=$(hostname -I | tr ' ' '\n' | grep '^10\.50\.' | head -n1)
  [[ -z "$LOCAL_IP" ]] && LOCAL_IP=$(hostname -I | awk '{print $1}')

  if confirm "Initiate replica set '${REPLICA_SET}' from this node now?"; then
    RS_OK=$(docker exec "$CONTAINER_NAME" mongosh --host localhost --port 27017 --quiet \
      -u "$MONGO_ROOT_USERNAME" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin \
      --eval "try { rs.status().ok } catch (e) { 0 }" 2>/dev/null || echo "0")

    if [[ "$RS_OK" == "1" ]]; then
      info "Replica set '${REPLICA_SET}' already initiated. Skipping."
    else
      info "Initiating replica set '${REPLICA_SET}' with primary ${LOCAL_IP}:${MONGO_PORT} ..."
      docker exec "$CONTAINER_NAME" mongosh --host localhost --port 27017 --quiet \
        -u "$MONGO_ROOT_USERNAME" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin \
        --eval "
          rs.initiate({
            _id: '${REPLICA_SET}',
            members: [
              { _id: 0, host: '${LOCAL_IP}:${MONGO_PORT}' }
            ]
          })
        "

      success "Replica set '${REPLICA_SET}' initiated with primary ${LOCAL_IP}:${MONGO_PORT}"
      echo ""
      echo "👉 To add replicas later, connect to this primary and run:"
      echo "   rs.add('<SECONDARY_IP>:<PORT>')"
    fi
  fi
fi

echo ""
success "MongoDB instance created!"
echo "🔹 Container:   $CONTAINER_NAME"
echo "🔹 Port:        $MONGO_PORT"
echo "🔹 Role:        $ROLE"
echo "🔹 Replica set: $REPLICA_SET"
echo "🔹 Root user:   $MONGO_ROOT_USERNAME"
echo "🔹 Root pass:   $MONGO_ROOT_PASSWORD"
echo "🔹 KeyFile:     $KEY_FILE (must be same on ALL members)"
echo ""
