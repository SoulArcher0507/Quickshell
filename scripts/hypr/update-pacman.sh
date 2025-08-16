#!/usr/bin/env bash
set -euo pipefail

elevate() {
  if command -v sudo >/dev/null 2>&1; then
    sudo -n "$@" || sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    echo "No sudo/doas/pkexec available." >&2
    exit 1
  fi
}

elevate pacman -Syu --noconfirm --needed
