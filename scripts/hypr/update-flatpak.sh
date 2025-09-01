#!/usr/bin/env bash
# Aggiorna Flatpak e alla fine stampa solo gli app-id aggiornati
set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak non trovato" >&2
  exit 1
fi

# App con update disponibile (solo application id)
before="$(flatpak remote-ls --updates --columns=application 2>/dev/null | awk 'NF' || true)"
[[ -z "${before}" ]] && exit 0

# Aggiorna (output su stderr)
flatpak update -y --noninteractive 1>&2

# Stampa solo gli app-id
printf "%s\n" "${before}"

