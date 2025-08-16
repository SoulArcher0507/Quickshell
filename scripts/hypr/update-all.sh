#!/usr/bin/env bash
set -euo pipefail

BASE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
LOCK="/tmp/hypr-update.lock"

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "Another update is already running."
  exit 0
fi

# Repo first
if [ -x "${BASE}/update-pacman.sh" ]; then
  "${BASE}/update-pacman.sh"
else
  if command -v yay >/dev/null 2>&1; then
    yay  -Syu --noconfirm --noeditmenu --nodiffmenu --cleanafter --removemake --answerclean All --answerdiff None
  elif command -v paru >/dev/null 2>&1; then
    paru -Syu --noconfirm --cleanafter --removemake --skipreview
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n pacman -Syu --noconfirm || sudo pacman -Syu --noconfirm
  fi
fi

# AUR, then Flatpak
[ -x "${BASE}/update-aur.sh" ] && "${BASE}/update-aur.sh" || true
[ -x "${BASE}/update-flatpak.sh" ] && "${BASE}/update-flatpak.sh" || true

echo "All updates completed."
