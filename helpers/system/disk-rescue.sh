#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/utils.sh"

info "🛟 Disk Emergency Rescue Setup"

#############################################
# Ensure fallocate exists
#############################################
if ! command -v fallocate &>/dev/null; then
  info "Installing util-linux..."
  sudo apt update -y
  sudo apt install -y util-linux
fi

#############################################
# Disk stats
#############################################

DISK_PATH="/"

TOTAL_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $2}')
USED_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $3}')
FREE_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $4}')
USED_PCT=$(df -P "$DISK_PATH" | awk 'NR==2 {print $5}')

TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_KB/1024/1024}")
USED_GB=$(awk "BEGIN {printf \"%.2f\", $USED_KB/1024/1024}")
FREE_GB=$(awk "BEGIN {printf \"%.2f\", $FREE_KB/1024/1024}")

info "Disk summary:"
info "• Total : ${TOTAL_GB} GB"
info "• Used  : ${USED_GB} GB (${USED_PCT})"
info "• Free  : ${FREE_GB} GB"

#############################################
# Ask percentage
#############################################

RESERVE_PCT=$(ask "Reserve how much % of total disk? (default 2%):")
[[ -z "$RESERVE_PCT" ]] && RESERVE_PCT=2

if ! [[ "$RESERVE_PCT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  error "Invalid percentage value"
  exit 1
fi

RESERVE_KB=$(awk "BEGIN {printf \"%d\", ($TOTAL_KB * $RESERVE_PCT) / 100}")
RESERVE_GB=$(awk "BEGIN {printf \"%.2f\", $RESERVE_KB/1024/1024}")

info "Will lock ${RESERVE_GB} GB (${RESERVE_PCT}%) as rescue space"

if (( RESERVE_KB > FREE_KB )); then
  error "Not enough free disk"
  exit 1
fi

#############################################
# Create rescue file
#############################################

RESCUE_FILE="/root/.disk-rescue"

if [[ -f "$RESCUE_FILE" ]]; then
  success "Rescue file already exists: $RESCUE_FILE"
  exit 0
fi

info "Creating rescue file..."

sudo fallocate -l "${RESERVE_KB}K" "$RESCUE_FILE"
sudo chmod 400 "$RESCUE_FILE"

success "Disk rescue file created"
success "Path: $RESCUE_FILE"
success "Size: ${R
