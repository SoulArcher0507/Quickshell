#!/usr/bin/env bash
set -euo pipefail

BASE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
LOCK="/tmp/hypr-update.lock"

# prevent concurrent runs
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "Another update is already running."
  exit 0
fi

echo "[repo] Updating official repositories..."
if [ -x "${BASE}/update-pacman.sh" ]; then
  "${BASE}/update-pacman.sh"
else
  # Fallback: just run pacman
  if command -v sudo >/dev/null 2>&1; then
    sudo -n pacman -Syu --noconfirm || sudo pacman -Syu --noconfirm
  elif command -v doas >/dev/null 2>&1; then
    doas pacman -Syu --noconfirm
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec pacman -Syu --noconfirm
  else
    echo "No sudo/doas/pkexec available to elevate pacman." >&2
  fi
fi

echo "[aur] Updating AUR packages..."
[ -x "${BASE}/update-aur.sh" ] && "${BASE}/update-aur.sh" || true

echo "[flatpak] Updating Flatpak apps..."
[ -x "${BASE}/update-flatpak.sh" ] && "${BASE}/update-flatpak.sh" || true

echo "All updates completed."
