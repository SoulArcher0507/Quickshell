#!/usr/bin/env bash
set -euo pipefail

# Se non hai flatpak, esci in silenzio
command -v flatpak >/dev/null 2>&1 || exit 0

# Preferisci le app installate con update disponibile
if flatpak list --app --columns=application 2>/dev/null | grep -q .; then
  flatpak list --app --columns=application 2>/dev/null | sort -u
else
  # Fallback: chiedi ai remoti (comunque senza sudo)
  flatpak remote-ls --updates --app --columns=application 2>/dev/null | sort -u
fi

