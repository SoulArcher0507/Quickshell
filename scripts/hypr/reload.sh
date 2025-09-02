#!/usr/bin/env bash
set -Eeuo pipefail

hyprctl reload
pkill -x qs

for i in {1..50}; do
  pgrep -x qs >/dev/null || break
  sleep 0.1
done

qs &

