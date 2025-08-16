#!/usr/bin/env bash
# Output: {"pacman":N,"aur":N,"flatpak":N,"total":N}
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

repo_count() {
  if has yay; then
    yay -Sy --color never >/dev/null 2>&1 || true
    yay  -Qu --repo --color never 2>/dev/null | wc -l
    return
  fi
  if has paru; then
    paru -Sy --color never >/dev/null 2>&1 || true
    paru -Qu --repo --color never 2>/dev/null | wc -l
    return
  fi
  if has checkupdates; then
    checkupdates 2>/dev/null | wc -l
    return
  fi
  # Fallback: DB temporaneo per evitare partial-upgrade
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  if pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1; then
    pacman -Sup --dbpath "$tmp" 2>/dev/null | wc -l
  else
    pacman -Qu 2>/dev/null | wc -l
  fi
}

aur_count() {
  if has yay;   then yay  -Qua --color never 2>/dev/null | wc -l; return; fi
  if has paru;  then paru -Qua --color never 2>/dev/null | wc -l; return; fi
  if has pikaur; then pikaur -Qua --nocolor 2>/dev/null | wc -l; return; fi
  echo 0
}

flatpak_count() {
  if has flatpak; then
    flatpak list --updates --app --columns=application 2>/dev/null | wc -l
  else
    echo 0
  fi
}

p="$(repo_count)"
a="$(aur_count)"
f="$(flatpak_count)"
t=$(( p + a + f ))
printf '{"pacman":%s,"aur":%s,"flatpak":%s,"total":%s}\n' "$p" "$a" "$f" "$t"
