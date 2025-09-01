#!/usr/bin/env bash
# Aggiorna pacchetti AUR e alla fine stampa solo i nomi aggiornati
set -euo pipefail

has(){ command -v "$1" >/dev/null 2>&1; }

helper=""
if   has yay;    then helper="yay"
elif has paru;   then helper="paru"
elif has pikaur; then helper="pikaur"
else
  echo "Nessun helper AUR trovato (installa yay/paru/pikaur)" >&2
  exit 1
fi

# Lista aggiornabili AUR (solo nomi)
case "$helper" in
  yay)    before="$("$helper" -Qua --quiet 2>/dev/null || true)";;
  paru)   before="$("$helper" -Qua --quiet 2>/dev/null || true)";;
  pikaur) before="$("$helper" -Qua 2>/dev/null | awk '{print $1}' || true)";;
esac

[[ -z "${before}" ]] && exit 0

# Aggiorna solo AUR
case "$helper" in
  yay)    "$helper" -Sua --noconfirm 1>&2;;
  paru)   "$helper" -Sua --noconfirm 1>&2;;
  pikaur) "$helper" -Sua --noconfirm 1>&2;;
esac

# Stampa solo i nomi
printf "%s\n" "${before}"

