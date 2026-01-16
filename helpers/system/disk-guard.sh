#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/utils.sh"
source "$BASE_DIR/helpers/mail.sh"

info "📊 Disk Usage Monitor Setup"

#############################################
# Ensure required packages
#############################################
if ! command -v df &>/dev/null; then
  error "df command missing (coreutils)"
  exit 1
fi

#############################################
# Ask inputs
#############################################

DISK_PATH=$(ask "Disk path to monitor (default /):")
[[ -z "$DISK_PATH" ]] && DISK_PATH="/"

THRESHOLD=$(ask "Alert threshold % (default 85):")
[[ -z "$THRESHOLD" ]] && THRESHOLD=85

info "Enter cron interval in MINUTES only (5–50)"
CRON_MIN=$(ask "Run every how many minutes? (default 5):")
[[ -z "$CRON_MIN" ]] && CRON_MIN=5

if ! [[ "$CRON_MIN" =~ ^[0-9]+$ ]] || (( CRON_MIN < 5 || CRON_MIN > 50 )); then
  error "Invalid minute value. Enter between 5 and 50."
  exit 1
fi

SCRIPT_INSTALL_PATH="/usr/local/bin/disk-guard.sh"

#############################################
# Install script
#############################################

info "Installing disk guard to $SCRIPT_INSTALL_PATH"
sudo cp "$0" "$SCRIPT_INSTALL_PATH"
sudo chmod +x "$SCRIPT_INSTALL_PATH"

#############################################
# Disk check
#############################################

USAGE=$(df -P "$DISK_PATH" | awk 'NR==2 {gsub("%",""); print $5}')

if (( USAGE >= THRESHOLD )); then
  MSG="Disk usage is ${USAGE}% on path ${DISK_PATH}"

  error "$MSG"
  send_mail "🚨 Disk Usage Alert" "$MSG"
else
  success "Disk usage OK: ${USAGE}%"
fi

#############################################
# Cron setup (idempotent)
#############################################

CRON_LINE="*/${CRON_MIN} * * * * $SCRIPT_INSTALL_PATH"

if ! sudo crontab -l 2>/dev/null | grep -Fq "$SCRIPT_INSTALL_PATH"; then
  info "Installing cron job..."
  (
    sudo crontab -l 2>/dev/null
    echo "$CRON_LINE"
  ) | sudo crontab -
  success "Cron installed: $CRON_LINE"
else
  success "Cron already exists"
fi
