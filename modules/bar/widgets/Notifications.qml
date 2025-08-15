import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Qt.labs.platform 1.1 as Labs
import "../../theme" as ThemePkg

Rectangle {
    id: root
    property int margin: 16

    // ====== manopole larghezza ======
    property real popupFrac: 0.30      // % dello schermo (0.55 = 55%)
    property int  popupMinWidth: 400   // min px
    property int  popupMaxWidth: 600   // max px
    property int  popupFixedWidth: 0   // se >0, usa questo valore fisso in px

    readonly property int popupWidth: {
        const scr = (root.window && root.window.screen) ? root.window.screen : Screen.primary
        const sw  = scr ? scr.geometry.width : 1280
        const wByFrac = Math.min(Math.max(sw * popupFrac, popupMinWidth), popupMaxWidth)
        Math.floor(popupFixedWidth > 0 ? popupFixedWidth : wByFrac)
    }

    // Forza la larghezza anche sulla finestra (PanelWindow/LayerShell)
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

    Component.onCompleted: _applyWidth()
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

    // Il wrapper esterno (notificationPanel in Bar) ha già sfondo/bordo
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

    // --- DO NOT DISTURB locale ---
    property bool doNotDisturb: false

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
        onNotification: (n) => { if (!root.doNotDisturb) n.tracked = true }
    }

    // ===== Cache icone =====
    property var _iconCache: ({})
    property var _artCache:  ({})

    // (Fallback non usati: li lascio in caso servano, ma NON vengono chiamati)
    function _fileExists(urlOrPath) {
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try { var xhr = new XMLHttpRequest(); xhr.open("GET", url, false); xhr.send()
              return xhr.responseText !== null && xhr.responseText.length > 0 } catch (e) { return false }
    }
    function _guessIconFileFromName(name) {
        const bases = [ "/usr/share/pixmaps/", "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/","/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/","/usr/share/icons/hicolor/32x32/apps/",
            "/usr/share/icons/hicolor/24x24/apps/","/usr/share/icons/hicolor/16x16/apps/",
            "/usr/share/icons/hicolor/scalable/apps/" ]
        const exts = [".png",".svg",".xpm"]
        for (let b of bases) for (let e of exts) { let p = b + name + e; if (_fileExists(p)) return "file://" + p }
        return ""
    }
    function _readDesktopIcon(desktopId) {
        if (!desktopId) return ""
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const appDirs = [
            "/usr/share/applications/",
            "/usr/local/share/applications/",
            home + "/.local/share/applications/"
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

    // ===== Versione veloce e cache-ata =====
    function _iconSourceFor(n) {
        const key = JSON.stringify({
            appIconName: n && n.appIconName, iconName: n && n.iconName,
            appIcon: n && n.appIcon, image: n && n.image,
            desktop: (n && (n.desktopEntry || n.desktopId)),
            appName: n && n.appName
        })
        if (_iconCache[key]) return _iconCache[key]

        function pick(s){ return (typeof s === "string" && s.length > 0) ? s : "" }

        const pathish = pick(n && n.image) || pick(n && n.appIcon)
        if (pathish) {
            const low = pathish.toLowerCase()
            const src = (low.startsWith("file:") || low.startsWith("qrc:") || low.startsWith("/"))
                        ? (low.startsWith("file:") ? pathish : "file://" + pathish)
                        : ("image://theme/" + pathish)
            _iconCache[key] = src; return src
        }

        const byName = pick(n && n.appIconName) || pick(n && n.iconName)
        if (byName) { _iconCache[key] = "image://theme/" + byName; return _iconCache[key] }

        const desk = pick(n && (n.desktopEntry || n.desktopId))
        if (desk) { _iconCache[key] = "image://theme/" + desk.replace(/\.desktop$/,""); return _iconCache[key] }

        const appn = pick(n && n.appName)
        if (appn) { _iconCache[key] = "image://theme/" + appn.replace(/\s+/g,"-").toLowerCase(); return _iconCache[key] }

        _iconCache[key] = "image://theme/dialog-information"
        return _iconCache[key]
    }

    function artFor(p){
        if (!p) return "image://theme/audio-x-generic"
        const key = JSON.stringify({ art:p.trackArtUrl, desk:p.desktopEntry, id:p.identity })
        if (_artCache[key]) return _artCache[key]

        if (p.trackArtUrl && p.trackArtUrl.length>0) { _artCache[key] = p.trackArtUrl; return _artCache[key] }
        if (p.desktopEntry && p.desktopEntry.length>0) {
            _artCache[key] = "image://theme/" + p.desktopEntry.replace(/\.desktop$/,""); return _artCache[key]
        }
        if (p.identity && p.identity.length>0) {
            _artCache[key] = "image://theme/" + p.identity.replace(/\s+/g,"-").toLowerCase(); return _artCache[key]
        }
        _artCache[key] = "image://theme/audio-x-generic"
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

            // Switch stile pillola
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
                    onClicked: root.doNotDisturb = !root.doNotDisturb
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // ===================== MEDIA MANAGER =====================
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

                // Freccia sinistra
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

                // Card centrale
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

                        // Header: cover PICCOLA + titolo a destra
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
                                      : "Nessun player MPRIS attivo"
                                color: primary
                                font.pixelSize: 16
                                font.family: "Fira Sans Semibold"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        // Controlli
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

                        // Pallini pagina
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

                // Freccia destra
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
        // =================== FINE MEDIA MANAGER =====================

        // Pulsante "Clear all" (customizzato con tema)
        Button {
            id: clearAllBtn
            Layout.alignment: Qt.AlignRight
            visible: server.trackedNotifications.values.length > 0
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

            // Riserva spazio alla scrollbar
            property int _vbarWidth: (vbar.visible ? Math.max(8, vbar.implicitWidth) + 4 : 0)
            rightMargin: _vbarWidth

            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: notificationList.contentHeight > notificationList.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }

            model: server.trackedNotifications

            delegate: Rectangle {
                width: notificationList.width - notificationList._vbarWidth
                radius: 6
                color: cardBg
                border.color: panelBorder

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
                            width: 20; height: 20
                            source: iconSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true; cache: true
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

                    Flow {
                        id: actionsFlow
                        width: parent.width
                        spacing: 6
                        visible: modelData.actions && modelData.actions.length > 0
                        height: visible ? implicitHeight : 0

                        Repeater {
                            model: modelData.actions
                            delegate: Button {
                                visible: modelData && modelData.text && modelData.text.length > 0
                                text: visible ? modelData.text : ""
                                background: Rectangle {
                                    radius: 6
                                    color: ThemePkg.Theme.surface(0.06)
                                    border.color: panelBorder
                                }
                                contentItem: Text {
                                    text: parent.Button.text
                                    color: primary
                                    font.pixelSize: 12
                                    font.family: "Fira Sans Semibold"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    padding: 6
                                }
                                onClicked: { if (modelData && modelData.invoke) modelData.invoke() }
                            }
                        }
                    }
                }

                implicitHeight: contentCol.implicitHeight + 16

// --- Close button coerente e centrato ---
Item {
    id: closeBtn
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 8
    width: 22
    height: width

    property bool hovered: false
    property bool pressed: false

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        antialiasing: true
        // Sfondo = stesso della finestra/pannello
        color: ThemePkg.Theme.background
        border.width: hovered ? 1.5 : 1
        border.color: hovered
            ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.accent, 0.85)
            : ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.14)
    }

    // X vettoriale, sempre perfettamente centrata
    Shape {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
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

            // Placeholder quando non ci sono notifiche
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: server.trackedNotifications.values.length === 0
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
