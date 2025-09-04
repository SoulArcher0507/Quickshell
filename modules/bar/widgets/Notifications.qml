import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Qt.labs.platform 1.1 as Labs
import Qt.labs.settings 1.1
import "../../theme" as ThemePkg
import "../../bar/widgets" as BarWidgets   // <-- DndState.qml sta in bar/widgets (aggiusta se serve)

Rectangle {
    id: root
    property int margin: 16

    // ====== manopole larghezza ======
    property real popupFrac: 0.30
    property int  popupMinWidth: 400
    property int  popupMaxWidth: 600
    property int  popupFixedWidth: 0

    readonly property int popupWidth: {
        const scr = (root.window && root.window.screen) ? root.window.screen : Screen.primary
        const sw  = scr ? scr.geometry.width : 1280
        const wByFrac = Math.min(Math.max(sw * popupFrac, popupMinWidth), popupMaxWidth)
        Math.floor(popupFixedWidth > 0 ? popupFixedWidth : wByFrac)
    }

    function _applyWidth() {
        root.width = popupWidth
        root.implicitWidth = popupWidth

        const w = QsWindow?.window || root.window
        if (w) {
            w.width = popupWidth
            if ("minimumWidth" in w) w.minimumWidth = popupWidth
            if ("maximumWidth" in w) w.maximumWidth = popupWidth
            if ("preferredWidth" in w) w.preferredWidth = popupWidth
            if ("contentWidth"  in w) w.contentWidth  = popupWidth
        }
    }
    
    Component.onCompleted: {
        _applyWidth()
        // sincronizza il runtime col valore persistito
        BarWidgets.DndState.dnd = notifSettings.dnd
    }
    onPopupWidthChanged:   _applyWidth()
    Connections {
        target: root.window ? root.window.screen : null
        function onGeometryChanged() { root._applyWidth() }
    }

    // ===== THEME mapping =====
    readonly property color panelBg:       ThemePkg.Theme.surface(0.10)
    readonly property color cardBg:        ThemePkg.Theme.surface(0.08)
    readonly property color panelBorder:   ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color primary:       ThemePkg.Theme.accent
    readonly property color textPrimary:   ThemePkg.Theme.foreground
    readonly property color textMuted:     ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.85)

    color: "transparent"
    radius: 0
    border.color: panelBorder
    border.width: 0
    clip: true

    implicitWidth: popupWidth
    Layout.preferredWidth: popupWidth
    Layout.minimumWidth: popupWidth
    Layout.maximumWidth: popupWidth
    height: implicitHeight
    implicitHeight: content.implicitHeight + margin * 2

    // --- DO NOT DISTURB: persistenza + stato runtime condiviso ---
    Settings {
        id: notifSettings
        category: "quickshell.notifications"
        property bool dnd: false
    }
    readonly property bool doNotDisturb: BarWidgets.DndState.dnd

    // Limite massimo finestra: metà schermo (fallback 540px)
    readonly property int maxPopupHeight: Math.floor(
        root.window && root.window.screen && root.window.screen.geometry
            ? root.window.screen.geometry.height * 0.5
            : 540
    )

    // --- Server notifiche ---
    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: true
        // Traccia SEMPRE: così compaiono nel pannello anche in DND
        onNotification: (n) => { n.tracked = true }
    }

    // ===== Cache icone =====
    property var _iconCache: ({})
    property var _artCache:  ({})

    function _fileExists(urlOrPath) {
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try { var xhr = new XMLHttpRequest(); xhr.open("GET", url, false); xhr.send()
              return xhr.responseText !== null && xhr.responseText.length > 0 } catch (e) { return false }
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
        ]
        const exts = [".png", ".svg", ".xpm"]
        for (let b of bases) for (let e of exts) {
            let p = b + name + e
            if (_fileExists(p)) return "file://" + p
        }
        return ""
    }

    function _readDesktopIcon(desktopId) {
        if (!desktopId) return ""
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const appDirs = [
            "/usr/share/applications/",
            "/usr/local/share/applications/",
            home + "/.local/share/applications/",
            "/var/lib/flatpak/exports/share/applications/",
            home + "/.local/share/flatpak/exports/share/applications/"
        ]

        for (let d of appDirs) {
            let f = d + (desktopId.endsWith(".desktop") ? desktopId : desktopId + ".desktop")
            if (_fileExists(f)) {
                try {
                    var xhr = new XMLHttpRequest()
                    xhr.open("GET", f.startsWith("file:") ? f : "file://" + f, false)
                    xhr.send()
                    let m = xhr.responseText.match(/^\s*Icon\s*=\s*(.+)\s*$/mi)
                    if (m && m[1]) return m[1].trim()
                } catch (e) {}
            }
        }
        return ""
    }
    function _themeUrl(name) { return "image://icon/" + name }

    function _iconSourceFor(n) {
        function pick(s){ return (s && typeof s === "string" && s.length > 0) ? s : "" }
        if (!n) return "image://theme/application-x-executable"

        const h = n.hints || {}

        const explicitPath = pick(h["image-path"]) || pick(h["app_icon"]) ||
                             pick(h["image"]) || pick(n.image) || pick(n.appIcon)
        if (explicitPath) {
            const p = explicitPath
            if (p.startsWith("file:") || p.startsWith("/") || p.startsWith("http"))
                return p.startsWith("file:") || p.startsWith("http") ? p : "file://" + p
            return _themeUrl(p)
        }

        const byName = pick(h["icon-name"]) || pick(n.appIconName) || pick(n.iconName)
        if (byName) {
            const guess = _guessIconFileFromName(byName)
            return guess || ("image://theme/" + byName)
        }

        const desk = pick(h["desktop-entry"]) || pick(n.desktopEntry) || pick(n.desktopId)
        if (desk) {
            const iconFromDesk = _readDesktopIcon(desk)
            if (iconFromDesk) {
                if (iconFromDesk.startsWith("file:") || iconFromDesk.startsWith("/"))
                    return iconFromDesk.startsWith("file:") ? iconFromDesk : "file://" + iconFromDesk
                const g = _guessIconFileFromName(iconFromDesk)
                return g || _themeUrl(iconFromDesk.replace(/\.desktop$/,""))
            }
            return _themeUrl(desk.replace(/\.desktop$/,""))
        }

        const appn = pick(n.appName)
        if (appn) {
            const name = appn.replace(/\s+/g,"-").toLowerCase()
            const g = _guessIconFileFromName(name)
            return g || _themeUrl(name)
        }

        const pathish = pick(n && n.image) || pick(n && n.appIcon)
        if (pathish) {
            const low = pathish.toLowerCase()
            const isUrl = low.startsWith("http:") || low.startsWith("https:") || low.startsWith("data:")
            const isFileLike = low.startsWith("file:") || low.startsWith("qrc:") || low.startsWith("/")
            const src = (isUrl || isFileLike)
                ? (low.startsWith("file:") || isUrl ? pathish : "file://" + pathish)
                : ("image://theme/" + pathish)
            _iconCache[key] = src; return src
        }

        return _themeUrl("dialog-information")
    }

    function artFor(p){
        if (!p) return "image://theme/audio-x-generic"
        const key = JSON.stringify({ art:p.trackArtUrl, desk:p.desktopEntry, id:p.identity })
        if (_artCache[key]) return _artCache[key]
        if (p.trackArtUrl && p.trackArtUrl.length>0) { _artCache[key] = p.trackArtUrl; return _artCache[key] }
        if (p.desktopEntry && p.desktopEntry.length>0) { _artCache[key] = _themeUrl(p.desktopEntry.replace(/\.desktop$/,"")) }
        if (p.identity && p.identity.length>0) { _artCache[key] = _themeUrl(p.identity.replace(/\s+/g,"-").toLowerCase()) }
        _artCache[key] = _themeUrl("audio-x-generic")
        return _artCache[key]
    }

    // ===== Layout =====
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 16

        // Pulsante DND
        RowLayout {
            id: dndRow
            Layout.fillWidth: true
            height: 30
            spacing: 10

            Text {
                text: "Do Not Disturb"
                color: primary
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: dndSwitch
                width: 46; height: 24; radius: 12
                color: root.doNotDisturb ? primary : ThemePkg.Theme.surface(0.08)
                border.color: panelBorder
                antialiasing: true
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: knob
                    width: 20; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.doNotDisturb ? parent.width - width - 2 : 2
                    color: ThemePkg.Theme.c15
                    antialiasing: true
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarWidgets.DndState.dnd = !BarWidgets.DndState.dnd
                        notifSettings.dnd       = BarWidgets.DndState.dnd
                    }
                }
            }
        }

        // ===================== MEDIA MANAGER =====================
        // (tutto invariato)
        Rectangle {
            id: mediaCarousel
            Layout.fillWidth: true
            radius: 12
            color: panelBg
            border.color: panelBorder
            border.width: 1
            clip: true
            implicitHeight: 170

            property var players: Mpris.players.values
            property int currentIndex: 0
            readonly property var cp: players.length>0 ? players[Math.min(currentIndex, players.length-1)] : null
            onPlayersChanged: if (currentIndex >= players.length) currentIndex = Math.max(0, players.length-1)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.alignment: Qt.AlignVCenter
                    height: 28
                    radius: 6
                    color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.background, 0.25)
                    visible: mediaCarousel.players.length > 1
                    Text { anchors.centerIn: parent; text: "‹"; color: primary; font.pixelSize: 18; font.family: "Fira Sans Semibold" }
                    MouseArea { anchors.fill: parent; enabled: parent.visible
                        onClicked: mediaCarousel.currentIndex =
                            (mediaCarousel.currentIndex - 1 + mediaCarousel.players.length) % mediaCarousel.players.length }
                }

                Rectangle {
                    id: card
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    height: parent.height
                    radius: 10
                    color: cardBg
                    border.color: panelBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Image {
                                id: art
                                source: root.artFor(mediaCarousel.cp)
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: mediaCarousel.cp
                                      ? (mediaCarousel.cp.trackTitle || mediaCarousel.cp.identity || "Media")
                                      : "No MPRIS player active"
                                color: primary
                                font.pixelSize: 16
                                font.family: "Fira Sans Semibold"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 40; height: 40; radius: 15
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? ThemePkg.Theme.surface(0.06) : ThemePkg.Theme.surface(0.04)
                                border.color: panelBorder
                                Text { anchors.centerIn: parent; text: ""; color: textPrimary; font.pixelSize: 16; font.family: "Fira Sans Semibold" }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.previous && mediaCarousel.cp.previous() }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 48; height: 48; radius: 17
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? ThemePkg.Theme.surface(0.06) : ThemePkg.Theme.surface(0.04)
                                border.color: panelBorder
                                Text {
                                    anchors.centerIn: parent
                                    text: (mediaCarousel.cp && mediaCarousel.cp.isPlaying) ? "" : ""
                                    color: textPrimary
                                    font.pixelSize: 25
                                    font.family: "Fira Sans Semibold"
                                }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.togglePlaying && mediaCarousel.cp.togglePlaying() }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 40; height: 40; radius: 15
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? ThemePkg.Theme.surface(0.06) : ThemePkg.Theme.surface(0.04)
                                border.color: panelBorder
                                Text { anchors.centerIn: parent; text: ""; color: textPrimary; font.pixelSize: 16; font.family: "Fira Sans Semibold" }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.next && mediaCarousel.cp.next() }
                            }
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            visible: mediaCarousel.players.length > 1
                            Repeater {
                                model: mediaCarousel.players.length
                                delegate: Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: index === mediaCarousel.currentIndex ? primary : panelBorder
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.alignment: Qt.AlignVCenter
                    height: 28
                    radius: 6
                    color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.background, 0.25)
                    visible: mediaCarousel.players.length > 1
                    Text { anchors.centerIn: parent; text: "›"; color: primary; font.pixelSize: 18; font.family: "Fira Sans Semibold" }
                    MouseArea { anchors.fill: parent; enabled: parent.visible
                        onClicked: mediaCarousel.currentIndex =
                            (mediaCarousel.currentIndex + 1) % mediaCarousel.players.length }
                }
            }
        }

        Button {
            id: clearAllBtn
            Layout.alignment: Qt.AlignRight
            visible: notificationList.count > 0
            text: "Clear all"
            background: Rectangle {
                radius: 8
                color: ThemePkg.Theme.surface(0.06)
                border.color: panelBorder
            }
            contentItem: Text {
                text: clearAllBtn.text
                color: primary
                font.pixelSize: 12
                font.family: "Fira Sans Semibold"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                padding: 8
            }
            onClicked: {
                // copia difensiva per evitare problemi mentre iteriamo
                const arr = (server.trackedNotifications.values || []).slice();
                for (let n of arr) {
                    try { n.dismiss(); } catch (e) {}
                }
            }
        }

        // Lista notifiche
        ListView {
            id: notificationList
            Layout.fillWidth: true

            Layout.preferredHeight: {
                const dndH = dndRow ? Math.max(dndRow.height, dndRow.implicitHeight) : 30
                let header = dndH + content.spacing
                header += mediaCarousel.implicitHeight + content.spacing
                if (clearAllBtn.visible) header += clearAllBtn.implicitHeight + content.spacing

                const contentMax = Math.max(120, root.maxPopupHeight - root.margin * 2)
                const listMax    = Math.max(80, contentMax - header)
                return Math.min(notificationList.contentHeight, listMax)
            }

            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            property int _vbarWidth: (vbar.visible ? Math.max(8, vbar.implicitWidth) + 4 : 0)
            rightMargin: _vbarWidth

            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: notificationList.contentHeight > notificationList.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }

            model: server.trackedNotifications



            // ====== DELEGATE ======
            delegate: Rectangle {
                width: notificationList.width - notificationList._vbarWidth
                radius: 6
                color: cardBg
                border.color: panelBorder
            
                // ogni elemento è una Notification, accessibile come modelData
                property string iconSource: root._iconSourceFor(modelData)
            
                Column {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6
            
                    Row {
                        id: headerRow
                        spacing: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
            
                        Image {
                            id: appIcon
                            width: 22; height: 22
                            source: iconSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true; cache: true
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    if (source.startsWith("image://icon/"))      { source = source.replace("image://icon/","image://theme/"); return }
                                    else if (source.startsWith("image://theme/")){ source = source.replace("image://theme/","image://icon/");  return }
                                    const h = (modelData && modelData.hints) ? modelData.hints : {}
                                    const desk = (modelData && (modelData.desktopEntry || modelData.desktopId)) || h["desktop-entry"]
                                    let fallback = ""
                                    if (desk) {
                                        const dIcon = root._readDesktopIcon(desk)
                                        if (dIcon) {
                                            fallback = (dIcon.startsWith("file:") || dIcon.startsWith("/"))
                                                ? (dIcon.startsWith("file:") ? dIcon : "file://" + dIcon)
                                                : root._guessIconFileFromName(dIcon)
                                        }
                                    }
                                    if (!fallback) {
                                        const byName = (modelData && (modelData.appIconName || modelData.iconName)) || h["icon-name"] || ""
                                        fallback = root._guessIconFileFromName(byName)
                                    }
                                    source = fallback || _themeUrl("application-x-executable")
                                }
                            }
                        }
            
                        Text {
                            id: titleText
                            text: modelData.summary
                            color: textPrimary
                            font.pixelSize: 14
                            font.bold: true
                            textFormat: Text.PlainText
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            width: parent.width - appIcon.width - headerRow.spacing
                        }
                    }
            
                    Text {
                        id: bodyText
                        width: parent.width
                        text: modelData.body
                        color: textMuted
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        elide: Text.ElideRight
                    }
            
                    // Azioni (se presenti)
                    Flow {
                        id: actionsFlow
                        width: parent.width
                        spacing: 8
                        visible: modelData.actions && modelData.actions.length > 0
                        height: visible ? implicitHeight : 0
            
                        Repeater {
                            model: modelData.actions
                            delegate: Button {
                                id: actionBtn
                                visible: modelData && modelData.text && modelData.text.length > 0
                                text: visible ? modelData.text : ""
                                leftPadding: 10; rightPadding: 10; topPadding: 6; bottomPadding: 6
                                implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                                implicitWidth: Math.max(96, contentItem.implicitWidth + leftPadding + rightPadding)
                                height: implicitHeight; width: implicitWidth
                                background: Rectangle {
                                    radius: 6
                                    color: ThemePkg.Theme.surface(0.06)
                                    border.color: panelBorder
                                }
                                contentItem: Text {
                                    text: actionBtn.text
                                    color: primary
                                    font.pixelSize: 12
                                    font.family: "Fira Sans Semibold"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                onClicked: { if (modelData && modelData.invoke) modelData.invoke() }
                            }
                        }
                    }
                }

                implicitHeight: contentCol.implicitHeight + 16

                // --- Close button
                Item {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    width: 22; height: width
                    property bool hovered: false
                    property bool pressed: false
                    Rectangle {
                        anchors.fill: parent
                        radius: width/2
                        antialiasing: true
                        color: ThemePkg.Theme.background
                        border.width: hovered ? 1.5 : 1
                        border.color: hovered
                            ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.accent, 0.85)
                            : ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.14)
                    }
                    Shape {
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height
                        antialiasing: true
                        opacity: pressed ? 0.8 : 1.0
                        ShapePath {
                            strokeWidth: 2.2
                            strokeColor: ThemePkg.Theme.accent
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            fillColor: "transparent"
                            PathMove { x: 7; y: 7 }
                            PathLine { x: closeBtn.width - 7; y: closeBtn.height - 7 }
                        }
                        ShapePath {
                            strokeWidth: 2.2
                            strokeColor: ThemePkg.Theme.accent
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            fillColor: "transparent"
                            PathMove { x: closeBtn.width - 7; y: 7 }
                            PathLine { x: 7; y: closeBtn.height - 7 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered:  closeBtn.hovered = true
                        onExited:   closeBtn.hovered = false
                        onPressed:  closeBtn.pressed = true
                        onReleased: closeBtn.pressed = false
                        onClicked:  modelData.dismiss()
                    }
                }
            }
            // ====== FINE DELEGATE ======

            // Messaggio quando non ci sono notifiche
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: notificationList.count === 0


                Text {
                    anchors.centerIn: parent
                    text: root.doNotDisturb ? "Do Not Disturb enabled" : "No notifications"
                    color: ThemePkg.Theme.withAlpha(textPrimary, 0.6)
                    font.pixelSize: 12
                }
            }
        }
    }
}
