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

THRESHOLD=$(ask "Alert threshold % (can be below current for testing, default 85):")
[[ -z "$THRESHOLD" ]] && THRESHOLD=85

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( THRESHOLD < 0 || THRESHOLD > 99 )); then
  error "Invalid threshold. Enter a value between 0 and 99."
  exit 1
fi

info "⚠️  You may set threshold below current usage to TEST mail alerts."

info "Enter cron interval in MINUTES only (1–50)"
CRON_MIN=$(ask "Run every how many minutes? (default 5):")
[[ -z "$CRON_MIN" ]] && CRON_MIN=5

if ! [[ "$CRON_MIN" =~ ^[0-9]+$ ]] || (( CRON_MIN < 1 || CRON_MIN > 50 )); then
  error "Invalid minute value. Enter between 1 and 50."
  exit 1
fi

SCRIPT_INSTALL_PATH="/usr/local/bin/disk-guard.sh"

#############################################
# Install / update script
#############################################

info "Installing disk guard to $SCRIPT_INSTALL_PATH"
sudo cp "$0" "$SCRIPT_INSTALL_PATH"
sudo chmod +x "$SCRIPT_INSTALL_PATH"

#############################################
# Immediate disk check
#############################################

USAGE=$(df -P "$DISK_PATH" | awk 'NR==2 {gsub("%",""); print $5}')

info "Current disk usage: ${USAGE}%"

if (( USAGE >= THRESHOLD )); then
  MSG="Disk usage is ${USAGE}% on path ${DISK_PATH} (threshold ${THRESHOLD}%)"

  error "$MSG"
  send_mail "🚨 Disk Usage Alert" "$MSG"
else
  success "Disk usage OK: ${USAGE}% (threshold ${THRESHOLD}%)"
fi

#############################################
# Cron setup (ask before overwrite)
#############################################

CRON_LINE="*/${CRON_MIN} * * * * $SCRIPT_INSTALL_PATH"
EXISTING_CRON=$(sudo crontab -l 2>/dev/null | grep "$SCRIPT_INSTALL_PATH" || true)

if [[ -n "$EXISTING_CRON" ]]; then
  info "Disk guard cron already exists:"
  info "$EXISTING_CRON"

  CONFIRM=$(ask "Do you want to overwrite this cron? (yes/no):")

  if [[ "${CONFIRM,,}" != "yes" ]]; then
    info "Keeping existing cron. No changes made."
    exit 0
  fi

  info "Overwriting existing disk-guard cron..."
else
  info "No existing disk-guard cron found. Installing new one..."
fi

(
  sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_INSTALL_PATH"
  echo "$CRON_LINE"
) | sudo crontab -

success "Disk guard cron is now set to:"
success "$CRON_LINE"

exit 0
