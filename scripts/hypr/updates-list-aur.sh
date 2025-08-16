#!/usr/bin/env bash
set -euo pipefail

if command -v yay >/dev/null 2>&1; then
  yay  -Qua --color never 2>/dev/null
elif command -v paru >/dev/null 2>&1; then
  paru -Qua --color never 2>/dev/null
elif command -v pikaur >/dev/null 2>&1; then
  pikaur -Qua --nocolor 2>/dev/null
else
  echo "No AUR helper available (yay/paru/pikaur)."
fi
