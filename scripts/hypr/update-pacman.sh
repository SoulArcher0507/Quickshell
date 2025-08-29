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

# If user uses yay/paru we can restrict to repo updates only; otherwise pacman
if command -v yay >/dev/null 2>&1; then
  yay  -Syu --repo --noconfirm --noeditmenu --nodiffmenu --cleanafter --removemake --answerclean All --answerdiff None
elif command -v paru >/dev/null 2>&1; then
  paru -Syu --repo --noconfirm --cleanafter --removemake --skipreview
else
  elevate pacman -Syu --noconfirm --needed
fi
