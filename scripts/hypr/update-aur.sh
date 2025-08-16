#!/usr/bin/env bash
set -euo pipefail

if command -v yay >/dev/null 2>&1; then
  yay  -Sua --noconfirm --noeditmenu --nodiffmenu --cleanafter --removemake --answerclean All --answerdiff None
elif command -v paru >/dev/null 2>&1; then
  paru -Sua --noconfirm --cleanafter --removemake --skipreview
elif command -v pikaur >/dev/null 2>&1; then
  pikaur -Sua --noconfirm --noedit
else
  echo "No AUR helper (yay/paru/pikaur) found." >&2
  exit 1
fi
