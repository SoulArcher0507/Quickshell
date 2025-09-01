#!/usr/bin/env bash
# Setta il wallpaper SENZA rofi.
# Uso: wallpaper.sh /percorso/assoluto/o/relativo/immagine.(jpg|png|webp|...)
#
# Cosa fa:
#  - verifica/risolve il percorso
#  - aggiorna i file "active" in ~/Pictures/Wallpapers/active/
#  - lancia swaybg (kill del precedente incluso)
#  - aggiorna i colori (pywal o ~/.config/wal/colors.sh se esiste)
#  - chiama eventuale reload dello stack (es. hypr reload, quickshell, ecc.)

set -Eeuo pipefail

WALL_DIR="${HOME}/Pictures/Wallpapers"
ACTIVE_DIR="${WALL_DIR}/active"
mkdir -p "$ACTIVE_DIR"

log() { printf '[wallpaper] %s\n' "$*" >&2; }

# --- argomento obbligatorio ---
if [[ $# -lt 1 ]]; then
  echo "Uso: $0 /path/to/image" >&2
  exit 2
fi

# Risolve percorso assoluto (se esiste)
PAPER_INPUT="$1"
if command -v readlink >/dev/null 2>&1; then
  PAPER="$(readlink -f -- "$PAPER_INPUT" || printf '%s' "$PAPER_INPUT")"
else
  # fallback rozzo se readlink non c'è
  case "$PAPER_INPUT" in
    /*) PAPER="$PAPER_INPUT" ;;
     *) PAPER="${PWD}/${PAPER_INPUT}" ;;
  esac
fi

[[ -f "$PAPER" ]] || { echo "File non trovato: $PAPER" >&2; exit 1; }

log "Imposto wallpaper: $PAPER"

# --- aggiorna 'active' (best-effort) ---
# manteniamo 'active.jpg' per compatibilità con script esistenti
cp -f -- "$PAPER" "$ACTIVE_DIR/active.jpg" 2>/dev/null || true

# Varianti utili se hai ImageMagick
if command -v magick >/dev/null 2>&1; then
  # blur (per sfondi di pannelli, se li usi)
  magick "$PAPER" -resize 75% "$ACTIVE_DIR/active_blur.jpg" 2>/dev/null || true
  magick "$ACTIVE_DIR/active_blur.jpg" -blur "50x30" "$ACTIVE_DIR/active_blur.jpg" 2>/dev/null || true
  # square (iconcine, ecc.)
  magick "$PAPER" -gravity Center -extent 1:1 "$ACTIVE_DIR/active_square.jpg" 2>/dev/null || true
fi

# --- imposta sfondo con swaybg (per tutti gli output) ---
pkill -x swaybg >/dev/null 2>&1 || true
(swaybg -i "$PAPER" -m fill >/dev/null 2>&1 & disown) || true

# genera varianti (facoltativo)
if command -v magick >/dev/null 2>&1; then
  magick "$PAPER" -resize 75% "$ACTIVE_DIR/active_blur.jpg" 2>/dev/null || true
  magick "$ACTIVE_DIR/active_blur.jpg" -blur "50x30" "$ACTIVE_DIR/active_blur.jpg" 2>/dev/null || true
  magick "$PAPER" -gravity Center -extent 1:1 "$ACTIVE_DIR/active_square.jpg" 2>/dev/null || true
fi

# NIENTE reload qui: ci pensa colors.sh
if [[ -x "$HOME/.config/wal/colors.sh" ]]; then
  "$HOME/.config/wal/colors.sh" "$PAPER" || true
elif command -v wal >/dev/null 2>&1; then
  wal -i "$PAPER" -n -q || true
fi
