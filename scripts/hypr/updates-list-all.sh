#!/usr/bin/env bash
set -euo pipefail

# Percorso predefinito coerente con la tua config
BASE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

echo "== pacman =="
"${BASE}/updates-list-pacman.sh" 2>/dev/null || true
echo
echo "== AUR =="
"${BASE}/updates-list-aur.sh" 2>/dev/null || true
echo
echo "== Flatpak =="
"${BASE}/updates-list-flatpak.sh" 2>/dev/null || true

