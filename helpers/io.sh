#!/usr/bin/env bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
success(){ echo -e "${GREEN}[OK]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

ask() {
  local prompt="$1"
  read -rp "$(echo -e "${YELLOW}[?]${RESET} ${prompt}") " REPLY
  echo "$REPLY"
}

confirm() {
  local prompt="$1"
  read -rp "$(echo -e "${YELLOW}[?]${RESET} ${prompt} (y/n): ")" choice
  case "$choice" in
    y|Y ) return 0 ;;
    * ) return 1 ;;
  esac
}
