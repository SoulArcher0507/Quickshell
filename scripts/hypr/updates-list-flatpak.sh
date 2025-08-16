#!/usr/bin/env bash
set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
  echo "Flatpak not installed."
  exit 0
fi

# application (branch) -> new-version (if reported)
if flatpak list --updates --app --columns=application,branch,version 2>/dev/null | grep -q .; then
  flatpak list --updates --app --columns=application,branch,version \
  | awk -F'\t' '{printf "%s (%s)%s\n",$1,$2, ($3!=""?" -> " $3:"") }'
else
  flatpak remote-ls --updates --app --columns=application,branch 2>/dev/null \
  | awk -F'\t' '{printf "%s (%s)\n",$1,$2}'
fi
