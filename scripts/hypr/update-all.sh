#!/usr/bin/env bash
# Aggiorna pacman+aur+flatpak e stampa solo i nomi/ID aggiornati
set -euo pipefail

has(){ command -v "$1" >/dev/null 2>&1; }

# --- Snapshot BEFORE ---
pac_before="$(pacman -Qu --quiet 2>/dev/null || true)"

aur_before=""
if   has yay;    then aur_before="$(yay -Qua --quiet 2>/dev/null || true)"
elif has paru;   then aur_before="$(paru -Qua --quiet 2>/dev/null || true)"
elif has pikaur; then aur_before="$(pikaur -Qua 2>/dev/null | awk '{print $1}' || true)"
fi

flat_before=""
if has flatpak; then
  flat_before="$(flatpak remote-ls --updates --columns=application 2>/dev/null | awk 'NF' || true)"
fi

# --- UPDATE ---
if has yay; then
  # yay può aggiornare repo+aur insieme
  yay -Syu --noconfirm 1>&2
elif has paru; then
  paru -Syu --noconfirm 1>&2
else
  # fallback: pacman poi (eventuale) helper solo AUR
  if [[ -n "${pac_before}" ]]; then
    sudo pacman -Syu --noconfirm 1>&2
  fi
  if command -v pikaur >/dev/null 2>&1 && [[ -n "${aur_before}" ]]; then
    pikaur -Sua --noconfirm 1>&2
  fi
fi

if [[ -n "${flat_before}" ]] && has flatpak; then
  flatpak update -y --noninteractive 1>&2
fi

# --- OUTPUT SOLO NOMI/ID ---
# NB: se uno snapshot era vuoto, non stampa nulla per quella categoria
{ [[ -n "${pac_before}"  ]] && printf "%s\n" "${pac_before}"; } || true
{ [[ -n "${aur_before}"  ]] && printf "%s\n" "${aur_before}"; } || true
{ [[ -n "${flat_before}" ]] && printf "%s\n" "${flat_before}"; } || true

