#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

if has yay; then
  yay -Sy --color never >/dev/null 2>&1 || true
  yay -Qu --repo --color never 2>/dev/null
  exit 0
fi

if has paru; then
  paru -Sy --color never >/dev/null 2>&1 || true
  paru -Qu --repo --color never 2>/dev/null
  exit 0
fi

if has checkupdates; then
  checkupdates 2>/dev/null
  exit 0
fi

# Fallback: DB temporaneo + parsing dei nomi dai .pkg.tar.*
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true
pacman -Sup --dbpath "$tmp" 2>/dev/null \
| sed -E 's#.*/##' \
| sed -E 's/\.pkg\.tar\.[^.]+$//' \
| sed -E 's/-[0-9][^-]*-[^-]*$//' \
| sort -u
