#!/usr/bin/env bash

send_mail() {
  local subject="$1"
  local body="$2"
  local host
  host="$(hostname -f)"

  # recipient must exist
  [[ ! -f /etc/infra-alert-email ]] && return 0

  local TO
  TO="$(tr -d '[:space:]' < /etc/infra-alert-email)"

  # basic email validation
  if [[ ! "$TO" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "[MAIL ERROR] Invalid recipient: $TO" >&2
    return 1
  fi

  echo -e "Host : $host\nTime : $(date)\n\n$body" \
    | mail -s "$subject [$host]" "$TO"
}
