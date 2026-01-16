#!/usr/bin/env bash
set -e

echo "📧 POSTFIX SMTP MAIL TEST"

#############################################
# REQUIRE ROOT (postfix runs as system daemon)
#############################################
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Run as root: sudo bash mail-test-postfix.sh"
  exit 1
fi

#############################################
# Ensure required packages
#############################################
if ! command -v mail &>/dev/null; then
  echo "Installing mailutils..."
  apt update -y
  apt install -y mailutils
fi

#############################################
# CONFIG (ONLY RECEIVER)
#############################################
MAIL_TO="salman.n@webshlok.com"

#############################################
# SEND TEST MAIL
#############################################
HOST="$(hostname -f)"
TIME="$(date)"

echo "Sending test mail via Postfix..."

echo "Postfix SMTP test

Host : $HOST
Time : $TIME

If you received this mail, POSTFIX SMTP IS WORKING." \
| mail -s " POSTFIX SMTP TEST [$HOST]" "$MAIL_TO"

#############################################
# CHECK QUEUE / LOG
#############################################
sleep 2

echo ""
echo "📦 Mail queue:"
mailq || true

echo ""
echo "📜 Last mail log:"
tail -n 20 /var/log/mail.log || true

echo ""
echo "✅ If mail arrived → Postfix is 100% OK"
