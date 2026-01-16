#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/utils.sh"

info "📧 Mail Alert Setup (SMTP)"

#############################################
# Ensure required packages
#############################################
if ! command -v msmtp &>/dev/null; then
  info "Installing msmtp..."
  sudo apt update -y
  sudo apt install -y msmtp msmtp-mta ca-certificates
fi

#############################################
# Check existing config
#############################################
if [[ -f /etc/msmtprc ]]; then
  info "Existing mail configuration detected at /etc/msmtprc"

  CONFIRM=$(ask "Do you want to overwrite existing mail config? (yes/no):")

  if [[ "${CONFIRM,,}" != "yes" ]]; then
    info "Keeping existing mail configuration. Exiting."
    exit 0
  fi

  info "Overwriting existing mail configuration..."
fi

#############################################
# Ask SMTP details
#############################################

SMTP_HOST=$(ask "SMTP host (e.g. smtp.gmail.com):")

SMTP_PORT=$(ask "SMTP port (default 587):")
[[ -z "$SMTP_PORT" ]] && SMTP_PORT=587

SMTP_USER=$(ask "SMTP username:")

# --- secure password input (no echo) ---
read -s -p "SMTP password: " SMTP_PASS
echo ""

MAIL_FROM=$(ask "From email address:")
MAIL_TO=$(ask "Alert recipient email:")

#############################################
# Validate
#############################################

for v in SMTP_HOST SMTP_USER SMTP_PASS MAIL_FROM MAIL_TO; do
  if [[ -z "${!v}" ]]; then
    error "$v cannot be empty"
    exit 1
  fi
done

#############################################
# Write msmtp config
#############################################

sudo tee /etc/msmtprc >/dev/null <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account alerts
host $SMTP_HOST
port $SMTP_PORT
user $SMTP_USER
password $SMTP_PASS
from $MAIL_FROM

account default : alerts
EOF

sudo chmod 600 /etc/msmtprc
sudo chown root:root /etc/msmtprc

#############################################
# Store default recipient
#############################################

echo "$MAIL_TO" | sudo tee /etc/infra-alert-email >/dev/null

success "Mail setup completed successfully"
success "Alerts will be sent to: $MAIL_TO"
