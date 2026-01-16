#!/usr/bin/env bash

send_mail() {
  local subject="$1"
  local body="$2"
  local hostname
  hostname="$(hostname)"

  [[ ! -f /etc/infra-alert-email ]] && return 0
  [[ ! -f /etc/msmtprc ]] && return 0
  command -v msmtp >/dev/null 2>&1 || return 0

  local TO
  TO="$(cat /etc/infra-alert-email)"

  {
    echo "Subject: ${subject} [${hostname}]"
    echo ""
    echo "Host : ${hostname}"
    echo "Time : $(date)"
    echo ""
    echo "$body"
  } | msmtp --config=/etc/msmtprc "$TO"
}
