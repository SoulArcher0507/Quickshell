#!/usr/bin/env bash
set -euo pipefail

# 1) Migliore: pacman-contrib -> checkupdates (zero sudo)
if command -v checkupdates >/dev/null 2>&1; then
  # "pkg ver -> newver"  -> prendi solo il nome
  checkupdates 2>/dev/null | awk '{print $1}' | sort -u
  exit 0
fi

# 2) Fallback robusto senza sudo: DB temporaneo + symlink del DB locale
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp"/{local,cache}
# Usa il DB locale in sola lettura (non serve sudo)
ln -s /var/lib/pacman/local "$tmp/local" 2>/dev/null || true

# Aggiorna solo i repo nel db temporaneo
pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true

# Elenco aggiornabili e tieni solo il nome
pacman -Qu --dbpath "$tmp" 2>/dev/null | awk '{print $1}' | sort -u || true

exit 0

