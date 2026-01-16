#!/usr/bin/env bash

send_mail() {
  local subject="$1"
  local body="$2"
  local hostname
  hostname="$(hostname)"

  # Preconditions
  [[ ! -f /etc/infra-alert-email ]] && return 0
  [[ ! -f /etc/msmtprc ]] && return 0
  command -v msmtp >/dev/null 2>&1 || return 0

  # Read & sanitize recipient
  local TO
  TO="$(tr -d '[:space:]' < /etc/infra-alert-email)"

  # Validate email
  if [[ ! "$TO" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "[MAIL ERROR] Invalid recipient address: $TO" >&2
    return 1
  fi

  # Extract FROM from msmtp config
  local FROM
  FROM="$(grep -E '^from ' /etc/msmtprc | awk '{print $2}')"

  {
    echo "From: Infra Alerts <$FROM>"
    echo "To: $TO"
    echo "Subject: ${subject} [${hostname}]"
    echo ""
    echo "Host : ${hostname}"
    echo "Time : $(date)"
    echo ""
    echo "$body"
  } | msmtp -t --config=/etc/msmtprc
}
