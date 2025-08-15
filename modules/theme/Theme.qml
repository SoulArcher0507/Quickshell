// modules/theme/Theme.qml
pragma Singleton
import QtQuick
import QtQml
import Qt.labs.platform 1.1
import Quickshell.Io    // FileView

QtObject {
    id: t

    // === Percorso del JSON generato dallo script colors.sh ===
    readonly property string jsonPath:
        StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"

    // === Stato interno con fallback sicuri (saranno sovrascritti dal file) ===
    property var _j: ({
        special: {
            background: "#222222",
            foreground: "#cccccc",
            cursor:     "#cccccc"
        },
        colors: {
            color0:  "#111111", color1:  "#dc2f2f", color2:  "#98c379", color3:  "#d19a66",
            color4:  "#61afef", color5:  "#c678dd", color6:  "#56b6c2", color7:  "#abb2bf",
            color8:  "#3e4451", color9:  "#e06c75", color10: "#98c379", color11: "#d19a66",
            color12: "#61afef", color13: "#c678dd", color14: "#56b6c2", color15: "#ffffff"
        },
        quickshell: {
            bg: "", fg: "", accent: "", accent2: "", success: "", warning: "", danger: "", muted: ""
        }
    })

    // ===== Lettura e watch del file (no XHR) =====
    // Nota: FileView ha i segnali 'fileChanged' e 'loaded' (non 'reloaded')
    property FileView _file: FileView {
        path: t.jsonPath
        watchChanges: true
        // carica subito
        Component.onCompleted: this.reload()
        // quando cambia su disco, ricarica
        onFileChanged: this.reload()
        // quando è caricato, applica il testo
        onLoaded: t._applyFromText(this.text())
    }

    function _applyFromText(txt) {
        if (!txt || txt === "") return;
        try {
            const parsed = JSON.parse(txt);
            function pick(a, b) { return (b !== undefined && b !== null && b !== "") ? b : a; }

            const s = parsed.special || {};
            const c = parsed.colors  || {};
            const q = parsed.quickshell || {};

            _j = {
                special: {
                    background: pick(_j.special.background, s.background),
                    foreground: pick(_j.special.foreground, s.foreground),
                    cursor:     pick(_j.special.cursor,     s.cursor)
                },
                colors: {
                    color0:  pick(_j.colors.color0,  c.color0),
                    color1:  pick(_j.colors.color1,  c.color1),
                    color2:  pick(_j.colors.color2,  c.color2),
                    color3:  pick(_j.colors.color3,  c.color3),
                    color4:  pick(_j.colors.color4,  c.color4),
                    color5:  pick(_j.colors.color5,  c.color5),
                    color6:  pick(_j.colors.color6,  c.color6),
                    color7:  pick(_j.colors.color7,  c.color7),
                    color8:  pick(_j.colors.color8,  c.color8),
                    color9:  pick(_j.colors.color9,  c.color9),
                    color10: pick(_j.colors.color10, c.color10),
                    color11: pick(_j.colors.color11, c.color11),
                    color12: pick(_j.colors.color12, c.color12),
                    color13: pick(_j.colors.color13, c.color13),
                    color14: pick(_j.colors.color14, c.color14),
                    color15: pick(_j.colors.color15, c.color15)
                },
                quickshell: {
                    bg:       pick(_j.quickshell.bg,       q.bg),
                    fg:       pick(_j.quickshell.fg,       q.fg),
                    accent:   pick(_j.quickshell.accent,   q.accent),
                    accent2:  pick(_j.quickshell.accent2,  q.accent2),
                    success:  pick(_j.quickshell.success,  q.success),
                    warning:  pick(_j.quickshell.warning,  q.warning),
                    danger:   pick(_j.quickshell.danger,   q.danger),
                    muted:    pick(_j.quickshell.muted,    q.muted)
                }
            }
        } catch(e) {
            console.warn("Theme.qml: JSON non valido:", e)
        }
    }

    // === Mapping stile Waybar ===
    readonly property color background: _pick("#222222", _j?.quickshell?.bg, _j?.special?.background)
    readonly property color foreground: _pick("#cccccc", _j?.quickshell?.fg, _j?.special?.foreground)
    readonly property color cursor:     _pick("#cccccc", _j?.special?.cursor)

    readonly property color c0:  _pick("#111111", _j?.colors?.color0)
    readonly property color c1:  _pick("#dc2f2f", _j?.colors?.color1)
    readonly property color c2:  _pick("#98c379", _j?.colors?.color2)
    readonly property color c3:  _pick("#d19a66", _j?.colors?.color3)
    readonly property color c4:  _pick("#61afef", _j?.colors?.color4)
    readonly property color c5:  _pick("#c678dd", _j?.colors?.color5)
    readonly property color c6:  _pick("#56b6c2", _j?.colors?.color6)
    readonly property color c7:  _pick("#abb2bf", _j?.colors?.color7)
    readonly property color c8:  _pick("#3e4451", _j?.colors?.color8)
    readonly property color c9:  _pick("#e06c75", _j?.colors?.color9)
    readonly property color c10: _pick("#98c379", _j?.colors?.color10)
    readonly property color c11: _pick("#d19a66", _j?.colors?.color11)
    readonly property color c12: _pick("#61afef", _j?.colors?.color12)
    readonly property color c13: _pick("#c678dd", _j?.colors?.color13)
    readonly property color c14: _pick("#56b6c2", _j?.colors?.color14)
    readonly property color c15: _pick("#ffffff", _j?.colors?.color15)

    readonly property color accent:  _pick(c4,  _j?.quickshell?.accent)
    readonly property color accent2: _pick(c6,  _j?.quickshell?.accent2)
    readonly property color success: _pick(c2,  _j?.quickshell?.success)
    readonly property color warning: _pick(c3,  _j?.quickshell?.warning)
    readonly property color danger:  _pick(c1,  _j?.quickshell?.danger)
    readonly property color muted:   _pick(c8,  _j?.quickshell?.muted)

    // ==== Utils ====
    function withAlpha(c, a) {
        function asRgb(x) {
            if (typeof x === "string") {
                let s = x.trim();
                if (s[0] === "#") s = s.slice(1);
                if (s.length === 3) s = s.split("").map(ch => ch + ch).join("");
                if (s.length === 8) s = s.slice(2); // #AARRGGBB -> RRGGBB
                const r = parseInt(s.slice(0,2), 16) / 255;
                const g = parseInt(s.slice(2,4), 16) / 255;
                const b = parseInt(s.slice(4,6), 16) / 255;
                return { r, g, b };
            } else if (x && x.r !== undefined && x.g !== undefined && x.b !== undefined) {
                return { r: x.r, g: x.g, b: x.b };
            } else {
                return asRgb("" + x);
            }
        }
        const rgb = asRgb(c);
        const alpha = (a === undefined || a === null) ? 1.0 : a;
        return Qt.rgba(rgb.r || 0, rgb.g || 0, rgb.b || 0, alpha);
    }

    function _toRgb(x) {
        if (typeof x === "string") {
            let s = x.trim(); if (s[0] === "#") s = s.slice(1);
            if (s.length === 3) s = s.split("").map(ch => ch + ch).join("");
            if (s.length === 8) s = s.slice(2);
            return { r: parseInt(s.slice(0,2),16)/255,
                     g: parseInt(s.slice(2,4),16)/255,
                     b: parseInt(s.slice(4,6),16)/255 };
        } else if (x && x.r !== undefined) {
            return { r: x.r, g: x.g, b: x.b };
        }
        return { r: 0, g: 0, b: 0 };
    }

    function mix(a, b, t) {
        const A = _toRgb(a), B = _toRgb(b);
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(A.r*(1-k)+B.r*k, A.g*(1-k)+B.g*k, A.b*(1-k)+B.b*k, 1.0);
    }

    // Surface “alzata”: background mescolato col foreground
    function surface(level) {
        return mix(background, foreground, Math.max(0, Math.min(1, level)));
    }

    function _pick(deflt /*, ...candidates */) {
        for (let i=1; i<arguments.length; ++i) {
            const v = arguments[i]
            if (v !== undefined && v !== null && v !== "") return v
        }
        return deflt
    }
}
