#!/usr/bin/env bash
# Aggiorna pacchetti repo (pacman) e alla fine stampa solo i nomi aggiornati
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman non trovato" >&2
  exit 1
fi

# Snapshot dei pacchetti aggiornabili (solo nomi)
before="$(pacman -Qu --quiet 2>/dev/null || true)"

# Se non c'è nulla da aggiornare, esci silenzioso
[[ -z "${before}" ]] && exit 0

# Aggiorna (reindirizza output su stderr)
sudo pacman -Syu --noconfirm 1>&2

# Stampa solo i nomi
printf "%s\n" "${before}"

