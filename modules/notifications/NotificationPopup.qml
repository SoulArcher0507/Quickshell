import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications as NS
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme" as ThemePkg          // <— cambia il path se serve
import "../bar/widgets" as BarWidgets  // <— DndState.qml sta in bar/widgets (aggiusta se serve)
import Qt.labs.platform 1.1 as Labs

// This version of NotificationPopup.qml improves the handling of notification
// icons. In particular it avoids using QQC2.Button with icon.name (which
// doesn't work for many apps like KDE Connect) and instead derives an icon
// source via heuristics similar to the notifications panel. It also provides
// a cache and file lookup helpers for theme and desktop-entry icons.

Scope {
    id: root

    required property var server

    // ======= COLORI TEMA (con fallback sicuri) =======
    readonly property bool hasTheme:
        !!ThemePkg && !!ThemePkg.Theme
        && (typeof ThemePkg.Theme.surface === "function")
        && (typeof ThemePkg.Theme.mix === "function")
        && (typeof ThemePkg.Theme.withAlpha === "function")

    // stessi nomi della Bar
    readonly property color moduleColor:       hasTheme ? ThemePkg.Theme.surface(0.10) : "#2b2b2b"
    readonly property color moduleBorderColor: hasTheme ? ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35) : "#505050"
    readonly property color moduleFontColor:   hasTheme ? ThemePkg.Theme.accent : "#4a9eff"
    readonly property color textColor:         hasTheme ? ThemePkg.Theme.foreground : "#f3f3f3"
    readonly property color subTextColor:      hasTheme ? ThemePkg.Theme.withAlpha(textColor, 0.90) : "#e6e6e6"
    readonly property color hoverFill:         hasTheme ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08) : "#3a3a3a"
    readonly property color criticalColor:     hasTheme ? ThemePkg.Theme.danger : "#ff5252"
    readonly property int   corner:            10

    ListModel { id: toastModel }

    // registro per evitare re-toast della stessa notifica
    property var _seenNotifs: []

    // ---- Icon cache and helper functions ----
    property var _iconCache: ({})

    function _fileExists(urlOrPath) {
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", url, false);
            xhr.send();
            return xhr.responseText !== null && xhr.responseText.length > 0;
        } catch (e) { return false; }
    }

    function _guessIconFileFromName(name) {
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const bases = [
            "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/32x32/apps/",
            "/usr/share/icons/hicolor/24x24/apps/",
            "/usr/share/icons/hicolor/16x16/apps/",
            "/usr/share/icons/hicolor/scalable/apps/",
            "/usr/share/pixmaps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/32x32/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/24x24/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/16x16/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/32x32/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/24x24/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/16x16/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/"
        ];
        const exts = [".png", ".svg", ".xpm"];
        for (let b of bases) {
            for (let e of exts) {
                let p = b + name + e;
                if (_fileExists(p)) return "file://" + p;
            }
        }
        return "";
    }

    function _readDesktopIcon(desktopId) {
        if (!desktopId) return "";
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const appDirs = [
            "/usr/share/applications/",
            "/usr/local/share/applications/",
            home + "/.local/share/applications/",
            "/var/lib/flatpak/exports/share/applications/",
            home + "/.local/share/flatpak/exports/share/applications/"
        ];
        for (let d of appDirs) {
            let f = d + (desktopId.endsWith(".desktop") ? desktopId : desktopId + ".desktop");
            if (_fileExists(f)) {
                try {
                    var xhr = new XMLHttpRequest();
                    xhr.open("GET", f.startsWith("file:") ? f : "file://" + f, false);
                    xhr.send();
                    let m = xhr.responseText.match(/^\s*Icon\s*=\s*(.+)\s*$/mi);
                    if (m && m[1]) return m[1].trim();
                } catch (e) {}
            }
        }
        return "";
    }

    function _themeUrl(name) { return "image://icon/" + name; }

    // Generate a list of potential icon names from a given identifier.
    // This helps resolve cases where the app_icon is a reverse domain name
    // (e.g. org.telegram.desktop) or contains hyphens/underscores.  It
    // produces candidates by stripping domain prefixes and splitting on
    // hyphens.  Each candidate is lower‑cased and sanitized.
    function _generateIconCandidates(name) {
        var list = [];
        if (!name || typeof name !== "string") return list;
        var n = name.replace(/\s+/g, "-").replace(/_/g, "-").toLowerCase();
        var parts = n.split('.');
        for (var i = 0; i < parts.length; ++i) {
            var suffix = parts.slice(i).join('-');
            if (suffix && list.indexOf(suffix) === -1) list.push(suffix);
        }
        var segs = n.split('-');
        for (var j = 0; j < segs.length; ++j) {
            var s = segs[j];
            if (s && list.indexOf(s) === -1) list.push(s);
        }
        return list;
    }

    function iconSourceFor(n) {
        function pick(s){ return (s && typeof s === "string" && s.length > 0) ? s : ""; }
        if (!n) return "image://theme/application-x-executable";
        const h = n.hints || {};
        const cacheKey = JSON.stringify({
            imagePath: pick(h["image-path"]) || pick(h["app_icon"]) || pick(h["image"]) || pick(n.image) || pick(n.appIcon),
            iconName:  pick(h["icon-name"])  || pick(n.appIconName)  || pick(n.iconName),
            desktop:   pick(h["desktop-entry"]) || pick(n.desktopEntry) || pick(n.desktopId),
            appName:   pick(n.appName)
        });
        if (_iconCache[cacheKey]) return _iconCache[cacheKey];
        const explicitPath = pick(h["image-path"]) || pick(h["app_icon"]) || pick(h["image"]) || pick(n.image) || pick(n.appIcon);
        if (explicitPath) {
            const p = explicitPath;
            let src = "";
            // If explicitPath is a real path or URL, use it directly.  Otherwise
            // try to resolve it as an icon name before falling back to theme.  KDE
            // Connect often provides a simple app_icon like "kdeconnect", so we
            // attempt to locate a real file via _guessIconFileFromName first.
            if (p.startsWith("file:") || p.startsWith("/") || p.startsWith("http")) {
                src = (p.startsWith("file:") || p.startsWith("http")) ? p : "file://" + p;
            } else {
                // Check if explicitPath refers to a desktop-entry ID. Some apps
                // set app_icon to a desktop file name (e.g. org.telegram.desktop).
                const dIcon = _readDesktopIcon(p);
                if (dIcon) {
                    if (dIcon.startsWith("file:") || dIcon.startsWith("/")) {
                        src = dIcon.startsWith("file:") ? dIcon : "file://" + dIcon;
                    } else {
                        const gdesk = _guessIconFileFromName(dIcon);
                        src = gdesk || _themeUrl(dIcon.replace(/\.desktop$/, ""));
                    }
                }
                // If not found via desktop entry, attempt to guess directly
                if (!src) {
                    const guessExplicit = _guessIconFileFromName(p);
                    src = guessExplicit;
                }
                // Attempt derived candidates when direct guess fails
                if (!src) {
                    const cands = _generateIconCandidates(p);
                    for (var ci = 0; ci < cands.length && !src; ++ci) {
                        const g = _guessIconFileFromName(cands[ci]);
                        if (g) { src = g; break; }
                    }
                }
                // Fallback to theme for the first candidate or original
                if (!src) {
                    const cands2 = _generateIconCandidates(p);
                    if (cands2.length > 0) {
                        src = _themeUrl(cands2[0]);
                    } else {
                        src = _themeUrl(p);
                    }
                }
            }
            _iconCache[cacheKey] = src; return src;
        }
        const byName = pick(h["icon-name"]) || pick(n.appIconName) || pick(n.iconName);
        if (byName) {
            // Attempt to resolve byName using file lookups and derived candidates
            let guess = _guessIconFileFromName(byName);
            let src = guess;
            if (!src) {
                const cands = _generateIconCandidates(byName);
                for (var ci = 0; ci < cands.length && !src; ++ci) {
                    const g = _guessIconFileFromName(cands[ci]);
                    if (g) { src = g; break; }
                }
            }
            if (!src) {
                const cands2 = _generateIconCandidates(byName);
                src = (cands2.length > 0) ? ("image://theme/" + cands2[0]) : ("image://theme/" + byName);
            }
            _iconCache[cacheKey] = src; return src;
        }
        const desk = pick(h["desktop-entry"]) || pick(n.desktopEntry) || pick(n.desktopId);
        if (desk) {
            const iconFromDesk = _readDesktopIcon(desk);
            if (iconFromDesk) {
                let src;
                if (iconFromDesk.startsWith("file:") || iconFromDesk.startsWith("/")) {
                    src = iconFromDesk.startsWith("file:") ? iconFromDesk : "file://" + iconFromDesk;
                } else {
                    const g = _guessIconFileFromName(iconFromDesk);
                    src = g || _themeUrl(iconFromDesk.replace(/\.desktop$/, ""));
                }
                _iconCache[cacheKey] = src; return src;
            }
            const src = _themeUrl(desk.replace(/\.desktop$/, ""));
            _iconCache[cacheKey] = src; return src;
        }
        const appn = pick(n.appName);
        if (appn) {
            const base = appn.replace(/\s+/g, "-").toLowerCase();
            const variants = [base, base.replace(/-/g, ""), base.replace(/-/g, "_"), base + "-app"];
            for (let v of variants) {
                const g = _guessIconFileFromName(v);
                if (g) { _iconCache[cacheKey] = g; return g; }
            }
            const src = _themeUrl(base);
            _iconCache[cacheKey] = src; return src;
        }
        const pathish = pick(n && n.image) || pick(n && n.appIcon);
        if (pathish) {
            const low = pathish.toLowerCase();
            const isUrl = low.startsWith("http:") || low.startsWith("https:") || low.startsWith("data:");
            const isFileLike = low.startsWith("file:") || low.startsWith("qrc:") || low.startsWith("/");
            let src;
            if (isUrl || isFileLike) {
                src = (low.startsWith("file:") || isUrl) ? pathish : "file://" + pathish;
            } else {
                src = "image://theme/" + pathish;
            }
            _iconCache[cacheKey] = src; return src;
        }
        const src = _themeUrl("dialog-information");
        _iconCache[cacheKey] = src; return src;
    }

    // --- monitor attivo (come prima) ---
    property var activeScreen: null
    function computeActiveScreen() {
        const fm = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        for (let i = 0; i < screens.length; ++i) {
            const s = screens[i];
            const m = Hyprland.monitorFor(s);
            if (fm && m && m.id === fm.id) return s;
        }
        return screens[0];
    }

    Component.onCompleted: {
        activeScreen = computeActiveScreen();
        // segna come viste quelle già tracciate
        try {
            if (server && server.trackedNotifications && server.trackedNotifications.values) {
                for (let n of server.trackedNotifications.values) {
                    if (_seenNotifs.indexOf(n) === -1) _seenNotifs.push(n);
                }
            }
        } catch (e) {}
    }
    Connections { target: Hyprland; ignoreUnknownSignals: true
        function onFocusedMonitorChanged() { root.activeScreen = root.computeActiveScreen(); } }
    Connections { target: Quickshell; ignoreUnknownSignals: true
        function onScreensChanged() { root.activeScreen = root.computeActiveScreen(); } }

    // --- add/remove toast ---
    function addToast(n) {
        if (!n || BarWidgets.DndState.dnd) return;     // blocca creazione in DND
        try { n.tracked = true; } catch(e) {}
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) return;
        toastModel.append({ notif: n });
    }
    function removeToast(n) {
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) { toastModel.remove(i); return; }
    }

    // tosta solo se non già vista e DND OFF
    Connections { target: server; ignoreUnknownSignals: true
        function onNotification(n) {
            if (!n) return;
            if (BarWidgets.DndState.dnd) return;
            if (_seenNotifs.indexOf(n) !== -1) return;
            _seenNotifs.push(n);
            addToast(n);
        } }
    // reagisci al cambio DND: se ON, chiudi i toast visibili
    Connections {
        target: BarWidgets.DndState
        function onDndChanged() {
            if (BarWidgets.DndState.dnd) toastModel.clear();
        }
    }
    // (solo rimozioni, niente add)
    Connections { target: server.trackedNotifications; ignoreUnknownSignals: true
        function onObjectRemovedPost(object, index)  { removeToast(object); }
        function onValueRemoved(key, value)          { removeToast(value); }
        function onRemoved(key, value)               { removeToast(value); } }

    PanelWindow {
        id: win
        anchors.top: true
        anchors.right: true
        margins.top: 16
        margins.right: 16
        exclusiveZone: 0
        color: "transparent"
        aboveWindows: true
        WlrLayershell.layer: WlrLayer.Overlay

        screen: root.activeScreen ?? (Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0] : null)
        visible: !BarWidgets.DndState.dnd && toastModel.count > 0   // nascondi i popup quando DND è ON

        implicitWidth: 420
        implicitHeight: column.implicitHeight
        height: column.implicitHeight

        Column {
            id: column
            anchors.right: parent.right
            spacing: 10
            Repeater {
                model: toastModel
                delegate: Toast { n: notif; width: 380 }
            }
        }

        // ===== Toast =====
        component Toast: Rectangle {
            id: toast
            property var n: null
            radius: corner
            color: moduleColor
            border.color: root.moduleBorderColor
            border.width: 1
            width: 380
            implicitHeight: content.implicitHeight + 24
            opacity: 0.0; y: 8
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on y       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Component.onCompleted: { opacity = 1.0; y = 0; }
            property bool hovered: false
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                function insideInteractive(mouse) {
                    function within(item) {
                        if (!item || !item.visible) return false;
                        var p = item.mapFromItem(toast, mouse.x, mouse.y);
                        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height;
                    }
                    return within(replyRow) || within(actionsFlow);
                }
                onPressed: {
                    if (insideInteractive(mouse)) {
                        mouse.accepted = false;
                        return;
                    }
                    autoClose.running = false;
                    toast.hovered = true;
                }
                onReleased: {
                    toast.hovered = false;
                    autoClose.running = !!toast.n && (toast.n.expireTimeout !== 0);
                }
                onClicked: {
                    if (insideInteractive(mouse)) return;
                    if (toast.n && typeof toast.n.dismiss === "function") toast.n.dismiss();
                }
            }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            border.color: hovered ? root.moduleFontColor : root.moduleBorderColor
            // Auto-close — SOLO popup: NON chiama expire/dismiss sulla notifica
            Timer {
                id: autoClose
                repeat: false
                running: !!toast.n && (toast.n.expireTimeout !== 0)
                interval: (toast.n && typeof toast.n.expireTimeout === "number"
                           ? (toast.n.expireTimeout > 0 ? toast.n.expireTimeout * 1000 : 5000)
                           : 5000)
                onTriggered: { root.removeToast(toast.n); }
            }
            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        IconImage {
                            id: richImage
                            anchors.fill: parent
                            source: (toast.n && toast.n.image) ? toast.n.image : ""
                            visible: source.length > 0
                        }
                        Image {
                            id: appIcon
                            anchors.fill: parent
                            visible: !richImage.visible
                            source: root.iconSourceFor(toast.n)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            cache: true
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    if (source.startsWith("image://icon/"))      { source = source.replace("image://icon/","image://theme/"); return; }
                                    else if (source.startsWith("image://theme/")){ source = source.replace("image://theme/","image://icon/");  return; }
                                    const h = toast.n && toast.n.hints ? toast.n.hints : {};
                                    const desk = (toast.n && (toast.n.desktopEntry || toast.n.desktopId)) || h["desktop-entry"];
                                    let fallback = "";
                                    if (desk) {
                                        const dIcon = root._readDesktopIcon(desk);
                                        if (dIcon) {
                                            fallback = (dIcon.startsWith("file:") || dIcon.startsWith("/"))
                                                ? (dIcon.startsWith("file:") ? dIcon : "file://" + dIcon)
                                                : root._guessIconFileFromName(dIcon);
                                        }
                                    }
                                    if (!fallback) {
                                        const byName = (toast.n && (toast.n.appIconName || toast.n.iconName)) || h["icon-name"] || "";
                                        // Try to guess from provided name and derived candidates
                                        let guess = root._guessIconFileFromName(byName);
                                        if (!guess && byName) {
                                            const cands = root._generateIconCandidates(byName);
                                            for (var ci = 0; ci < cands.length && !guess; ++ci) {
                                                const g = root._guessIconFileFromName(cands[ci]);
                                                if (g) { guess = g; break; }
                                            }
                                        }
                                        fallback = guess || fallback;
                                        // Try explicit field names as icon names (non path) when above fails
                                        if (!fallback) {
                                            const explicit = (toast.n && (toast.n.appIcon || toast.n.image)) || "";
                                            if (explicit && typeof explicit === "string") {
                                                const isPathLike = explicit.startsWith("file:") || explicit.startsWith("/") || explicit.includes(":");
                                                if (!isPathLike) {
                                                    let g2 = root._guessIconFileFromName(explicit);
                                                    if (!g2) {
                                                        // Derive candidates
                                                        const cand2s = root._generateIconCandidates(explicit);
                                                        for (var j = 0; j < cand2s.length && !g2; ++j) {
                                                            const g = root._guessIconFileFromName(cand2s[j]);
                                                            if (g) { g2 = g; break; }
                                                        }
                                                    }
                                                    fallback = g2 || fallback;
                                                }
                                            }
                                        }
                                    }
                                    source = fallback || root._themeUrl("application-x-executable");
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: (toast.n ? (toast.n.summary || toast.n.appName) : "")
                            color: root.moduleFontColor
                            font.bold: true
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (toast.n && toast.n.body) ? toast.n.body : ""
                            textFormat: Text.RichText
                            wrapMode: Text.Wrap
                            color: root.subTextColor
                            font.pixelSize: 12
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: (toast.n
                            ? (toast.n.urgency === NS.NotificationUrgency.Critical ? root.criticalColor
                               : (toast.n.urgency === NS.NotificationUrgency.Low
                                  ? (ThemePkg && ThemePkg.Theme ? ThemePkg.Theme.withAlpha(root.textColor, 0.55) : "#cccccc")
                                  : root.moduleFontColor))
                            : root.moduleFontColor)
                        Layout.alignment: Qt.AlignTop
                    }
                }
                Flow {
                    id: actionsFlow
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !!(toast.n && toast.n.actions && toast.n.actions.length > 0)
                    Repeater {
                        model: (toast.n && toast.n.actions) ? toast.n.actions : []
                        delegate: QQC2.Button {
                            id: actionBtn
                            required property var modelData
                            property string label: (modelData && (modelData.text || modelData.label || modelData.title || ""))
                            text: label
                            hoverEnabled: true
                            leftPadding: 10; rightPadding: 10; topPadding: 6; bottomPadding: 6
                            implicitHeight: Math.max(28, actionText.implicitHeight + topPadding + bottomPadding)
                            implicitWidth:  Math.max(88, actionText.implicitWidth  + leftPadding + rightPadding)
                            background: Rectangle {
                                radius: corner
                                color: actionBtn.hovered ? hoverFill : (hasTheme ? ThemePkg.Theme.surface(0.06) : "#353535")
                                border.color: moduleBorderColor
                                border.width: 1
                            }
                            contentItem: Text {
                                id: actionText
                                text: actionBtn.text
                                color: moduleFontColor
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                            onClicked: if (modelData && typeof modelData.invoke === "function") modelData.invoke();
                        }
                    }
                }
                RowLayout {
                    id: replyRow
                    visible: (!!toast.n && toast.n.hasInlineReply)
                    Layout.fillWidth: true
                    spacing: 8
                    QQC2.TextField {
                        id: replyField
                        Layout.fillWidth: true
                        placeholderText: (toast.n && toast.n.inlineReplyPlaceholder) ? toast.n.inlineReplyPlaceholder : "Rispondi…"
                        color: root.textColor
                        background: Rectangle {
                            radius: corner
                            color: hasTheme ? ThemePkg.Theme.surface(0.06) : "#353535"
                            border.color: root.moduleBorderColor
                            border.width: 1
                        }
                        onAccepted: sendBtn.clicked();
                    }
                    QQC2.Button {
                        id: sendBtn
                        text: "Invia"
                        hoverEnabled: true
                        padding: 8
                        background: Rectangle {
                            radius: corner
                            color: sendBtn.hovered ? root.hoverFill : (hasTheme ? ThemePkg.Theme.surface(0.06) : "#353535")
                            border.color: root.moduleBorderColor
                            border.width: 1
                        }
                        contentItem: Text {
                            text: sendBtn.text
                            color: root.moduleFontColor
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            if (toast.n) {
                                toast.n.sendInlineReply(replyField.text);
                                replyField.clear();
                                toast.n.dismiss();
                            }
                        }
                    }
                }
            }
            Connections {
                target: toast.n
                ignoreUnknownSignals: true
                function onClosed(reason) { root.removeToast(toast.n); }
                function onTrackedChanged() { if (toast.n && !toast.n.tracked) root.removeToast(toast.n); }
            }
        }
    }
}