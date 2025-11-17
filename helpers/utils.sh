#!/usr/bin/env bash

generate_password() {
  openssl rand -hex 16
}

safe_mkdir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
}

safe_copy() {
  local source="$1"
  local dest="$2"
  cp "$source" "$dest"
}
