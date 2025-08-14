import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris   // MPRIS per il media manager

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
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

    // ===== Helpers icone/app =====
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
        const appDirs = [ "/usr/share/applications/","/usr/local/share/applications/",
            Qt.resolvedUrl("~/.local/share/applications/").replace("qml/","") ]
        for (let d of appDirs) {
            let f = d + desktopId + (desktopId.endsWith(".desktop") ? "" : ".desktop")
            if (_fileExists(f)) {
                try { var xhr = new XMLHttpRequest(); xhr.open("GET", f.startsWith("file:") ? f : "file://" + f, false)
                      xhr.send(); let m = xhr.responseText.match(/^\s*Icon\s*=\s*(.+)\s*$/mi)
                      if (m && m[1]) return m[1].trim() } catch (e) {}
            }
        }
        return ""
    }
    function _iconSourceFor(n) {
        function pick(s){return (typeof s==="string"&&s.length>0)?s:""}
        const direct = [pick(n&&n.appIconName),pick(n&&n.iconName),pick(n&&n.appIcon),pick(n&&n.image)]
        for (let name of direct) {
            if (!name) continue
            const lower = name.toLowerCase()
            const looksPath = lower.startsWith("/")||lower.startsWith("file:")||lower.startsWith("qrc:")||name.indexOf(".")!==-1
            if (looksPath) return lower.startsWith("file:") ? name : "file://" + name
            let file = _guessIconFileFromName(name); return file.length>0 ? file : "image://theme/" + name
        }
        const desktopId = pick(n&&(n.desktopEntry||n.desktopId||n.desktop))
        if (desktopId) {
            const icon = _readDesktopIcon(desktopId)
            if (icon) {
                const lower = icon.toLowerCase()
                const looksPath = lower.startsWith("/")||lower.startsWith("file:")||icon.indexOf(".")!==-1
                if (looksPath) return lower.startsWith("file:") ? icon : "file://" + icon
                let f = _guessIconFileFromName(icon); return f.length>0 ? f : ("image://theme/" + icon)
            }
        }
        const appName = pick(n&&n.appName)
        if (appName) {
            let norm = appName.replace(/\s+/g,"-").toLowerCase()
            let f = _guessIconFileFromName(norm); if (f.length===0) f=_guessIconFileFromName(appName)
            if (f.length>0) return f; return "image://theme/" + norm
        }
        return "image://theme/dialog-information"
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
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
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
            implicitHeight: 166

            // IMPORTANT: binding diretto, così si aggiorna quando compaiono/spariscono player
            property var players: Mpris.players.values
            property int currentIndex: 0
            readonly property var cp: players.length > 0 ? players[Math.min(currentIndex, players.length-1)] : null
            onPlayersChanged: if (currentIndex >= players.length) currentIndex = Math.max(0, players.length-1)

            // --- Progress (robusto a µs/ms/s) ---
            function _toSeconds(v) { if (!v || v<0) return 0; if (v>1e7) return Math.floor(v/1e6); if (v>1e4) return Math.floor(v/1e3); return Math.floor(v) }
            function _fmt(s)      { let m=Math.floor(s/60), ss=s%60; return (m<10?"0"+m:m)+":"+(ss<10?"0"+ss:ss) }

            property int durationSec: 0
            property int positionSec: 0
            property bool _seeking: false

            // Poll leggero per posizione/durata
            Timer {
                interval: 500; running: true; repeat: true
                onTriggered: {
                    if (mediaCarousel.cp) {
                        const p = mediaCarousel.cp
                        mediaCarousel.durationSec  = mediaCarousel._toSeconds(p.length !== undefined ? p.length : (p.trackLength || 0))
                        mediaCarousel.positionSec  = mediaCarousel._toSeconds(p.position || 0)
                        if (!mediaCarousel._seeking) {
                            progressSlider.to = Math.max(1, mediaCarousel.durationSec)
                            progressSlider.value = Math.min(mediaCarousel.positionSec, progressSlider.to)
                        }
                    } else {
                        mediaCarousel.durationSec = 0
                        mediaCarousel.positionSec = 0
                        progressSlider.to = 1
                        if (!mediaCarousel._seeking) progressSlider.value = 0
                    }
                }
            }

            function artFor(p){
                if (!p) return "image://theme/audio-x-generic"
                if (p.trackArtUrl && p.trackArtUrl.length>0) return p.trackArtUrl
                if (p.desktopEntry && p.desktopEntry.length>0) {
                    const icon = _readDesktopIcon(p.desktopEntry)
                    if (icon) {
                        const lower = icon.toLowerCase()
                        const looksPath = lower.startsWith("/")||lower.startsWith("file:")||icon.indexOf(".")!==-1
                        return looksPath ? (lower.startsWith("file:")?icon:"file://"+icon)
                                        : (_guessIconFileFromName(icon) || "image://theme/" + icon)
                    }
                }
                return "image://theme/audio-x-generic"
            }

            // ********* QUI: RowLayout (non Row) *********
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
                    height: parent.height - 16
                    radius: 10
                    color: "#333333"
                    border.color: "#444444"
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Header: copertina + titolo (RowLayout per far riempire il testo)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Image {
                                id: art
                                source: mediaCarousel.artFor(mediaCarousel.cp)
                                width: 48; height: 48
                                fillMode: Image.PreserveAspectCrop
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

                        // Controlli
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text { anchors.centerIn: parent; text: "«"; color: ok ? "#dddddd" : "#777777"; font.pixelSize: 14; font.family: "Fira Sans Semibold" }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.previous && mediaCarousel.cp.previous() }
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text {
                                    anchors.centerIn: parent
                                    text: (mediaCarousel.cp && mediaCarousel.cp.isPlaying) ? "▮▮" : "▶"
                                    color: ok ? "#dddddd" : "#777777"; font.pixelSize: 14; font.family: "Fira Sans Semibold"
                                }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.togglePlaying && mediaCarousel.cp.togglePlaying() }
                            }
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                readonly property bool ok: !!mediaCarousel.cp
                                color: ok ? "#444444" : "#333333"
                                border.color: "#555555"
                                Text { anchors.centerIn: parent; text: "»"; color: ok ? "#dddddd" : "#777777"; font.pixelSize: 14; font.family: "Fira Sans Semibold" }
                                MouseArea { anchors.fill: parent; enabled: ok
                                    onClicked: mediaCarousel.cp && mediaCarousel.cp.next && mediaCarousel.cp.next() }
                            }
                        }

                        // Progresso + cursore (seek)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Slider {
                                id: progressSlider
                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, mediaCarousel.durationSec)
                                value: Math.min(mediaCarousel.positionSec, to)
                                enabled: !!mediaCarousel.cp
                                onPressedChanged: {
                                    mediaCarousel._seeking = pressed
                                    if (!pressed && mediaCarousel.cp) {
                                        const target = Math.floor(value)
                                        const cur = mediaCarousel.positionSec
                                        if (typeof mediaCarousel.cp.setPosition === "function")
                                            mediaCarousel.cp.setPosition(target)
                                        else if (typeof mediaCarousel.cp.seek === "function")
                                            mediaCarousel.cp.seek((target - cur) * 1000000) // delta in µs
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: mediaCarousel._fmt(Math.min(progressSlider.value, mediaCarousel.durationSec)); color: "#bbbbbb"; font.pixelSize: 11 }
                                Item { Layout.fillWidth: true; height: 1 }
                                Text { text: mediaCarousel.durationSec>0 ? mediaCarousel._fmt(mediaCarousel.durationSec) : "--:--"; color: "#bbbbbb"; font.pixelSize: 11 }
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
                            source: root._iconSourceFor(modelData)
                            fillMode: Image.PreserveAspectFit
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
