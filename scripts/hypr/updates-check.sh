#!/usr/bin/env bash
# Output: {"pacman":N,"aur":N,"flatpak":N,"total":N}
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

repo_count() {
  if has yay; then
    yay -Sy --color never >/dev/null 2>&1 || true
    ( yay  -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi
  if has paru; then
    paru -Sy --color never >/dev/null 2>&1 || true
    ( paru -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi
  if has checkupdates; then
    ( checkupdates 2>/dev/null || true ) | wc -l
    return
  fi
  # Fallback using temporary db when pacman-contrib isn't installed
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  ( pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true )
  ( pacman -Sup --dbpath "$tmp" 2>/dev/null || true ) | wc -l
}

aur_count() {
  if has yay;    then ( yay   -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has paru;   then ( paru  -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has pikaur; then ( pikaur -Qua --nocolor    2>/dev/null || true ) | wc -l; return; fi
  echo 0
}

flatpak_count() {
  if ! has flatpak; then echo 0; return; fi
  # Prefer remote-ls --updates when available
  if flatpak remote-ls --updates --columns=application >/dev/null 2>&1; then
    flatpak remote-ls --updates --columns=application 2>/dev/null | wc -l
    return
  fi
  # Fallback: list --updates (older versions might lack --columns)
  ( flatpak list --updates --app 2>/dev/null || true ) | awk 'NR>1' | wc -l
}

p="$(repo_count)"
a="$(aur_count)"
f="$(flatpak_count)"
t=$(( p + a + f ))
printf '{"pacman":%s,"aur":%s,"flatpak":%s,"total":%s}
' "$p" "$a" "$f" "$t"
