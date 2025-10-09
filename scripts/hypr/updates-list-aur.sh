#!/usr/bin/env bash
set -euo pipefail

if command -v yay >/dev/null 2>&1; then
  yay  -Qua --color never 2>/dev/null | awk '{print $1}' | sort -u
  exit 0
fi

if command -v paru >/dev/null 2>&1; then
  paru -Qua --color never 2>/dev/null | awk '{print $1}' | sort -u
  exit 0
fi

if command -v pikaur >/dev/null 2>&1; then
  pikaur -Qua --nocolor     2>/dev/null | awk '{print $1}' | sort -u
  exit 0
fi

# Nessun helper AUR disponibile: esci in silenzio
exit 0

