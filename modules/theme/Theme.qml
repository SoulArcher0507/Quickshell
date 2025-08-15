// modules/theme/Theme.qml
pragma Singleton
import QtQuick
import QtQml            // per Timer
import Qt.labs.platform 1.1

QtObject {
    id: t

    // === Percorso del JSON generato dallo script colors.sh ===
    readonly property string jsonPath:
        StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"

    // === Dati grezzi ===
    property var _raw: ({})
    property string _last: ""

    // === Mapping stile Waybar ===
    // special
    readonly property color background: _pick("#222222", _raw?.quickshell?.bg, _raw?.special?.background)
    readonly property color foreground: _pick("#cccccc", _raw?.quickshell?.fg, _raw?.special?.foreground)
    readonly property color cursor:     _pick("#cccccc", _raw?.special?.cursor)

    // palette 0..15
    readonly property color c0:  _pick("#111111", _raw?.colors?.color0)
    readonly property color c1:  _pick("#dc2f2f", _raw?.colors?.color1)
    readonly property color c2:  _pick("#98c379", _raw?.colors?.color2)
    readonly property color c3:  _pick("#d19a66", _raw?.colors?.color3)
    readonly property color c4:  _pick("#61afef", _raw?.colors?.color4)
    readonly property color c5:  _pick("#c678dd", _raw?.colors?.color5)
    readonly property color c6:  _pick("#56b6c2", _raw?.colors?.color6)
    readonly property color c7:  _pick("#abb2bf", _raw?.colors?.color7)
    readonly property color c8:  _pick("#3e4451", _raw?.colors?.color8)
    readonly property color c9:  _pick("#e06c75", _raw?.colors?.color9)
    readonly property color c10: _pick("#98c379", _raw?.colors?.color10)
    readonly property color c11: _pick("#d19a66", _raw?.colors?.color11)
    readonly property color c12: _pick("#61afef", _raw?.colors?.color12)
    readonly property color c13: _pick("#c678dd", _raw?.colors?.color13)
    readonly property color c14: _pick("#56b6c2", _raw?.colors?.color14)
    readonly property color c15: _pick("#ffffff", _raw?.colors?.color15)

    // alias “quickshell”
    readonly property color accent:  _pick(c4,  _raw?.quickshell?.accent)
    readonly property color accent2: _pick(c6,  _raw?.quickshell?.accent2)
    readonly property color success: _pick(c2,  _raw?.quickshell?.success)
    readonly property color warning: _pick(c3,  _raw?.quickshell?.warning)
    readonly property color danger:  _pick(c1,  _raw?.quickshell?.danger)
    readonly property color muted:   _pick(c8,  _raw?.quickshell?.muted)

    // ==== Utils ====
    function withAlpha(c, a) {
        function asRgb(x) {
            if (typeof x === "string") {
                let s = x.trim();
                if (s[0] === "#") s = s.slice(1);
                if (s.length === 3) {                 // #RGB -> #RRGGBB
                    s = s.split("").map(ch => ch + ch).join("");
                }
                if (s.length === 8) {                 // #AARRGGBB -> RRGGBB
                    s = s.slice(2);
                }
                const r = parseInt(s.slice(0,2), 16) / 255;
                const g = parseInt(s.slice(2,4), 16) / 255;
                const b = parseInt(s.slice(4,6), 16) / 255;
                return { r, g, b };
            } else if (x && x.r !== undefined && x.g !== undefined && x.b !== undefined) {
                // colore già in forma Qt.rgba(...)
                return { r: x.r, g: x.g, b: x.b };
            } else {
                // tentativo: trasformalo in stringa e riprova
                return asRgb("" + x);
            }
        }
        const rgb = asRgb(c);
        const alpha = (a === undefined || a === null) ? 1.0 : a;
        return Qt.rgba(rgb.r || 0, rgb.g || 0, rgb.b || 0, alpha);
    }

    // --- util per mescolare colori e creare superfici leggibili ---
    function _toRgb(x) {
        // accetta "#RRGGBB", "#AARRGGBB", "#RGB" o Qt.rgba(...)
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

    // Surface “alzata”: background mescolato col foreground (come un lighten soft)
    function surface(level) {            // level consigliati: 0.06, 0.10, 0.14
        return mix(background, foreground, level);
    }


    function _pick(deflt /*, ...candidates */) {
        for (let i=1; i<arguments.length; ++i) {
            const v = arguments[i]
            if (v !== undefined && v !== null && v !== "") return v
        }
        return deflt
    }

    function _loadOnce() {
        try {
            const url = "file://" + jsonPath
            const xhr = new XMLHttpRequest()
            xhr.open("GET", url)
            xhr.onreadystatechange = function() {
                // status 0 (file://) o 200 (http)
                if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 0 || xhr.status === 200)) {
                    if (xhr.responseText && xhr.responseText !== _last) {
                        _last = xhr.responseText
                        _raw = JSON.parse(xhr.responseText)
                    }
                }
            }
            xhr.send()
        } catch (e) {
            // fallback sui valori di default
        }
    }

    // <<< FIX: il Timer è una PROPERTY, non un figlio “sfuso” >>>
    property Timer _watcher: Timer {
        interval: 750
        running: true
        repeat: true
        onTriggered: t._loadOnce()
    }

    Component.onCompleted: _loadOnce()
}
