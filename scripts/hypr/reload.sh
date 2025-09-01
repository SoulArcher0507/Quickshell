#!/usr/bin/env bash
set -Eeuo pipefail

# Evita corse multiple
lock="$HOME/.cache/quickshell-reload.lock"
mkdir -p "$(dirname "$lock")"
exec 9>"$lock"
flock -n 9 || exit 0

# Ricarica Hyprland se presente (non è blocking)
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload || true
fi

# Preferisci systemd user se esiste un servizio quickshell
if command -v systemctl >/dev/null 2>&1 && systemctl --user list-units --type=service --all | grep -q '^quickshell\.service'; then
  systemctl --user restart quickshell.service || true
  exit 0
fi

# Fallback manuale: chiudi qs e riaprila in modo sicuro
pkill -x qs || true

# aspetta che chiuda davvero
for i in {1..50}; do
  pgrep -x qs >/dev/null || break
  sleep 0.1
done

# NON toccare swaybg qui: lo imposta già wallpaper.sh

# riapri qs in background, senza legarla alla shell chiamante
if command -v qs >/dev/null 2>&1; then
  nohup qs >/dev/null 2>&1 &
elif command -v quickshell >/dev/null 2>&1; then
  nohup quickshell >/dev/null 2>&1 &
fi

exit 0
