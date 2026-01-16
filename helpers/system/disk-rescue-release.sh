#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/utils.sh"

RESCUE_FILE="/root/.disk-rescue"
DISK_PATH="/"

info "🧯 Disk Emergency Rescue Release"

#############################################
# Check rescue file exists
#############################################

if [[ "$EUID" -ne 0 ]]; then
  error "This script must be run as root"
  error "Run: sudo helpers/system/disk-rescue-release.sh"
  exit 1
fi

if [[ ! -f "$RESCUE_FILE" ]]; then
  info "No rescue file found at $RESCUE_FILE"
  info "Nothing to release"
  exit 0
fi

#############################################
# Disk stats BEFORE
#############################################

TOTAL_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $2}')
USED_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $3}')
FREE_KB=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $4}')
USED_PCT=$(df -P "$DISK_PATH" | awk 'NR==2 {print $5}')

USED_GB=$(awk "BEGIN {printf \"%.2f\", $USED_KB/1024/1024}")
FREE_GB=$(awk "BEGIN {printf \"%.2f\", $FREE_KB/1024/1024}")

info "Disk usage BEFORE release:"
info "• Used : ${USED_GB} GB (${USED_PCT})"
info "• Free : ${FREE_GB} GB"

#############################################
# Confirm action
#############################################

warn "This will DELETE the disk rescue file and FREE space."
warn "Use this ONLY when disk is FULL or system is unstable."

CONFIRM=$(ask "Type YES to confirm release:")

if [[ "$CONFIRM" != "YES" ]]; then
  info "Release cancelled by user"
  exit 0
fi

#############################################
# Remove rescue file
#############################################

info "Releasing disk rescue space..."
sudo rm -f "$RESCUE_FILE"

#############################################
# Disk stats AFTER
#############################################

USED_KB_AFTER=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $3}')
FREE_KB_AFTER=$(df -Pk "$DISK_PATH" | awk 'NR==2 {print $4}')
USED_PCT_AFTER=$(df -P "$DISK_PATH" | awk 'NR==2 {print $5}')

USED_GB_AFTER=$(awk "BEGIN {printf \"%.2f\", $USED_KB_AFTER/1024/1024}")
FREE_GB_AFTER=$(awk "BEGIN {printf \"%.2f\", $FREE_KB_AFTER/1024/1024}")

success "Disk rescue space released successfully"

info "Disk usage AFTER release:"
info "• Used : ${USED_GB_AFTER} GB (${USED_PCT_AFTER})"
info "• Free : ${FREE_GB_AFTER} GB"
