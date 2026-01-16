#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/helpers/io.sh"
source "$BASE_DIR/helpers/utils.sh"

info "📧 Mail Alert Setup (SMTP via Postfix)"

#############################################
# Must run as root
#############################################
if [[ "$EUID" -ne 0 ]]; then
  error "Run as root: sudo bash mail-setup.sh"
  exit 1
fi

#############################################
# Ensure required packages
#############################################
if ! command -v postfix &>/dev/null; then
  info "Installing postfix + mailutils..."
  apt update -y
  apt install -y postfix mailutils libsasl2-modules
fi

#############################################
# Ask SMTP details (UNCHANGED UX)
#############################################

SMTP_HOST=$(ask "SMTP host (e.g. smtp.gmail.com):")
SMTP_PORT=$(ask "SMTP port (default 465):")
[[ -z "$SMTP_PORT" ]] && SMTP_PORT=465

SMTP_USER=$(ask "SMTP username:")

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
# Mail domain
#############################################
echo "${MAIL_FROM#*@}" > /etc/mailname

#############################################
# Configure Postfix relay (SAFE overwrite of relay parts)
#############################################

postconf -e "relayhost = [$SMTP_HOST]:$SMTP_PORT"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_tls_wrappermode = yes"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_sasl_tls_security_options = noanonymous"
postconf -e "smtp_generic_maps = hash:/etc/postfix/generic"

#############################################
# SASL credentials
#############################################
cat > /etc/postfix/sasl_passwd <<EOF
[$SMTP_HOST]:$SMTP_PORT $SMTP_USER:$SMTP_PASS
EOF

chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

#############################################
# Global sender rewrite
#############################################
cat > /etc/postfix/generic <<EOF
@$(hostname -f) $MAIL_FROM
EOF

postmap /etc/postfix/generic

#############################################
# Restart postfix
#############################################
systemctl restart postfix

#############################################
# Store default recipient
#############################################
echo "$MAIL_TO" > /etc/infra-alert-email

#############################################
# Final test
#############################################
echo "Mail setup test from $(hostname)" \
| mail -s "SMTP ALERT TEST" "$MAIL_TO"

success "Mail setup completed successfully"
success "Alerts will be sent to: $MAIL_TO"





