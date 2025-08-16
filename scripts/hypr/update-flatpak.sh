#!/usr/bin/env bash
set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
  exit 0
fi

flatpak update --app -y --noninteractive --no-related
flatpak uninstall --unused -y || true
