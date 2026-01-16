#!/usr/bin/env bash
set -e

echo "📧 DIRECT SMTP MAIL TEST (NO HELPERS)"

#############################################
# REQUIRE ROOT (SMTP password inside)
#############################################
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Run as root: sudo bash mail-test-direct.sh"
  exit 1
fi

#############################################
# Install msmtp if missing
#############################################
if ! command -v msmtp &>/dev/null; then
  echo "Installing msmtp..."
  apt update -y
  apt install -y msmtp ca-certificates
fi

#############################################
# === FILL THESE VALUES ===
#############################################

SMTP_HOST="mail.977-24-24-365.com"
SMTP_PORT="465"
SMTP_USER="serveralerts@mail.977-24-24-365.com"
SMTP_PASS="Salman@786"
MAIL_FROM="serveralerts@mail.977-24-24-365.com"
MAIL_TO="salman.n@webshlok.com"

#############################################
# TEMP CONFIG
#############################################
TMP_CFG="/tmp/msmtp-test.conf"

cat > "$TMP_CFG" <<EOF
defaults
auth on
tls on
tls_starttls off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /tmp/msmtp-test.log

account test
host $SMTP_HOST
port $SMTP_PORT
user $SMTP_USER
password $SMTP_PASS
from $MAIL_FROM

account default : test
EOF

chmod 600 "$TMP_CFG"

#############################################
# SEND MAIL
#############################################
echo "Sending test mail..."

{
  echo "Subject: ✅ SMTP TEST SUCCESS ($(hostname))"
  echo ""
  echo "Host: $(hostname)"
  echo "Time: $(date)"
  echo ""
  echo "If you received this, SMTP is WORKING."
} | msmtp --file="$TMP_CFG" "$MAIL_TO"

#############################################
# RESULT
#############################################
echo "✅ MAIL SENT SUCCESSFULLY"
echo "Log: /tmp/msmtp-test.log"
