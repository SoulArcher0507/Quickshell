import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Qt.labs.platform 1.1 as Labs   // <-- per StandardPaths

Rectangle {
    id: root
    property int margin: 16
    // >> Larghezza forzata e stabile <<
    readonly property int popupWidth: Math.floor(
        root.window && root.window.screen && root.window.screen.geometry
            ? Math.min(Math.max(root.window.screen.geometry.width * 0.38, 520), 720)
            : 560
    )
    width: popupWidth
    implicitWidth: popupWidth
    height: implicitHeight

    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
    clip: true
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

    // ===== Cache icone (evita I/O sincrono) =====
    property var _iconCache: ({})
    property var _artCache:  ({})

    // --- Helpers originali (rimangono per fallback) ---
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
        Rectangle {
            id: dndButton
            Layout.fillWidth: true
            height: 30
            radius: 6
            color: root.doNotDisturb ? "#444444" : "#333333"
            border.color: "#555555"
            clip: true
            Text {
                anchors.centerIn: parent
                text: root.doNotDisturb ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                color: "#ffffff"; font.pixelSize: 14; font.family: "Fira Sans Semibold"
            }
            MouseArea { anchors.fill: parent; onClicked: root.doNotDisturb = !root.doNotDisturb }
        }

        // ===================== MEDIA MANAGER =====================
        Rectangle {
            id: mediaCarousel
            Layout.fillWidth: true
            radius: 12
            color: "#2b2b2b"
            border.color: "#555555"
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
                    radius: 6; color: "#00000044"
                    visible: mediaCarousel.players.length > 1
                    Text { anchors.centerIn: parent; text: "‹"; color: "#ff7f32"; font.pixelSize: 18; font.family: "Fira Sans Semibold" }
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
                    color: "#333333"
                    border.color: "#444444"
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
                                color: "#ff7f32"
                                font.pixelSize: 16
                                font.family: "Fira Sans Semibold"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        // Controlli sotto (prec / play-pausa / succ)
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text { anchors.centerIn: parent; text: "«"; color: ok ? "#dddddd" : "#777777";
                                       font.pixelSize: 13; font.family: "Fira Sans Semibold" }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.previous && mediaCarousel.cp.previous() }
                            }
                            Rectangle {
                                width: 34; height: 34; radius: 17
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text {
                                    anchors.centerIn: parent
                                    text: (mediaCarousel.cp && mediaCarousel.cp.isPlaying) ? "▮▮" : "▶"
                                    color: ok ? "#dddddd" : "#777777"
                                    font.pixelSize: 13
                                    font.family: "Fira Sans Semibold"
                                }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.togglePlaying && mediaCarousel.cp.togglePlaying() }
                            }
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text { anchors.centerIn: parent; text: "»"; color: ok ? "#dddddd" : "#777777";
                                       font.pixelSize: 13; font.family: "Fira Sans Semibold" }
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
                                delegate: Rectangle { width: 6; height: 6; radius: 3; color: index === mediaCarousel.currentIndex ? "#ff7f32" : "#555555" }
                            }
                        }
                    }
                }

                // Freccia destra
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.alignment: Qt.AlignVCenter
                    height: 28
                    radius: 6; color: "#00000044"
                    visible: mediaCarousel.players.length > 1
                    Text { anchors.centerIn: parent; text: "›"; color: "#ff7f32"; font.pixelSize: 18; font.family: "Fira Sans Semibold" }
                    MouseArea { anchors.fill: parent; enabled: parent.visible
                        onClicked: mediaCarousel.currentIndex =
                            (mediaCarousel.currentIndex + 1) % mediaCarousel.players.length }
                }
            }
        }
        // =================== FINE MEDIA MANAGER =====================

        // Barra "Clear all"
        Rectangle {
            id: clearBar
            Layout.fillWidth: true
            height: 36
            visible: server.trackedNotifications.values.length > 0
            radius: 6
            color: "#2e2e2e"
            border.color: "#555555"
            Button {
                id: clearAllBtn
                anchors.centerIn: parent
                text: "Clear all"
                onClicked: {
                    while (server.trackedNotifications.values.length > 0)
                        server.trackedNotifications.values[0].dismiss()
                }
            }
        }

        // Lista notifiche
        ListView {
            id: notificationList
            Layout.fillWidth: true
            Layout.preferredHeight: {
                let header = dndButton.height + content.spacing
                header += mediaCarousel.implicitHeight + content.spacing
                if (clearBar.visible) header += clearBar.height + content.spacing
                const contentMax = Math.max(120, root.maxPopupHeight - root.margin * 2)
                const listMax = Math.max(80, contentMax - header)
                Math.min(notificationList.contentHeight, listMax)
            }
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ScrollBar.vertical: ScrollBar {
                policy: notificationList.contentHeight > notificationList.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }

            model: server.trackedNotifications

            delegate: Rectangle {
                width: notificationList.width
                radius: 6
                color: "#333333"
                border.color: "#555555"

                // calcola una sola volta l'icona (no I/O, no ricalcoli)
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
                            color: "#ffffff"
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
                        text: modelData.body
                        color: "#dddddd"
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
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
                                onClicked: { if (modelData && modelData.invoke) modelData.invoke() }
                            }
                        }
                    }
                }

                implicitHeight: contentCol.implicitHeight + 16

                ToolButton {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    text: "✕"
                    onClicked: modelData.dismiss()
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: server.trackedNotifications.values.length === 0
                Text {
                    anchors.centerIn: parent
                    text: root.doNotDisturb ? "Do Not Disturb enabled" : "No notifications"
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
            }
        }
    }
}
