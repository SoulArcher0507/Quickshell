import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
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

        onNotification: (n) => {
            if (!root.doNotDisturb) {
                n.tracked = true
            }
        }
    }

    // Helper: funzioni per risolvere un'icona in una sorgente valida per Image
    function _fileExists(urlOrPath) {
        // accetta sia "file:///..." che "/..."
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, false) // sync ok per lookup rapido
            xhr.send()
            // Per file locali status può essere 0: ci basiamo sulla presenza di dati
            return xhr.responseText !== null && xhr.responseText.length > 0
        } catch (e) {
            return false
        }
    }

    function _guessIconFileFromName(name) {
        // tenta alcuni percorsi standard (png/svg)
        const bases = [
            "/usr/share/pixmaps/",
            "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/32x32/apps/",
            "/usr/share/icons/hicolor/24x24/apps/",
            "/usr/share/icons/hicolor/16x16/apps/",
            "/usr/share/icons/hicolor/scalable/apps/"
        ]
        const exts = [".png", ".svg", ".xpm"]
        for (let b of bases) {
            for (let e of exts) {
                let p = b + name + e
                if (_fileExists(p)) return "file://" + p
            }
        }
        return ""
    }

    function _readDesktopIcon(desktopId) {
        // cerca il file .desktop e ritorna icona (nome o path)
        const appDirs = [
            "/usr/share/applications/",
            "/usr/local/share/applications/",
            Qt.resolvedUrl("~/.local/share/applications/").replace("qml/","") // best effort
        ]
        for (let d of appDirs) {
            let f = d + desktopId + (desktopId.endsWith(".desktop") ? "" : ".desktop")
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

    function _iconSourceFor(n) {
        function pick(s) { return (typeof s === "string" && s.length > 0) ? s : "" }

        // 1) candidati diretti dal server
        const directNames = [
            pick(n && n.appIconName),
            pick(n && n.iconName),
            pick(n && n.appIcon),
            pick(n && n.image) // alcune app passano un path
        ]
        for (let name of directNames) {
            if (!name) continue
            const lower = name.toLowerCase()
            const looksPath = lower.startsWith("/") || lower.startsWith("file:") ||
                              lower.startsWith("qrc:") || name.indexOf(".") !== -1
            if (looksPath) return lower.startsWith("file:") ? name : "file://" + name
            // prova tema
            let themed = "image://theme/" + name
            // non abbiamo modo certo di sapere se il provider disegnerà,
            // ma proviamo anche a risolvere un file reale come fallback:
            let file = _guessIconFileFromName(name)
            return file.length > 0 ? file : themed
        }

        // 2) desktop-entry hint -> leggi .desktop e ricava Icon
        const desktopId = pick(n && (n.desktopEntry || n.desktopId || n.desktop))
        if (desktopId) {
            const iconFromDesktop = _readDesktopIcon(desktopId)
            if (iconFromDesktop) {
                const lower = iconFromDesktop.toLowerCase()
                const looksPath = lower.startsWith("/") || lower.startsWith("file:") ||
                                  iconFromDesktop.indexOf(".") !== -1
                if (looksPath) return lower.startsWith("file:") ? iconFromDesktop : "file://" + iconFromDesktop
                // nome -> prova file reale, poi tema
                let file = _guessIconFileFromName(iconFromDesktop)
                return file.length > 0 ? file : ("image://theme/" + iconFromDesktop)
            }
        }

        // 3) ultima spiaggia: prova con appName -> file o tema
        const appName = pick(n && n.appName)
        if (appName) {
            let normalized = appName.replace(/\s+/g, "-").toLowerCase()
            let file = _guessIconFileFromName(normalized)
            if (file.length === 0) file = _guessIconFileFromName(appName)
            if (file.length > 0) return file
            return "image://theme/" + normalized
        }

        // 4) fallback generico
        return "image://theme/dialog-information"
    }


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

            Text {
                anchors.centerIn: parent
                text: root.doNotDisturb ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.doNotDisturb = !root.doNotDisturb
            }
        }

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
                    while (server.trackedNotifications.values.length > 0) {
                        server.trackedNotifications.values[0].dismiss()
                    }
                }
            }
        }

        // Lista notifiche
        ListView {
            id: notificationList
            Layout.fillWidth: true
            // cresce fino a metà schermo, poi scorre
            Layout.preferredHeight: {
                let header = dndButton.height + content.spacing
                if (clearBar.visible) header += clearBar.height + content.spacing
                const contentMax = Math.max(120, root.maxPopupHeight - root.margin * 2)
                const listMax = Math.max(80, contentMax - header)
                Math.min(notificationList.contentHeight, listMax)
            }
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            // Scrollbar verticale
            ScrollBar.vertical: ScrollBar {
                policy: notificationList.contentHeight > notificationList.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }

            // Modello: notifiche tracciate
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

                    // Header con icona app + titolo
                    Row {
                        id: headerRow
                        spacing: 8
                        anchors.left: parent.left
                        anchors.right: parent.right

                        // Icona app (immagine tema o file)
                        Image {
                            id: appIcon
                            width: 20
                            height: 20
                            source: root._iconSourceFor(modelData)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            cache: true
                        }

                        // Titolo (summary)
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

                    // Corpo
                    Text {
                        id: bodyText
                        text: modelData.body
                        color: "#dddddd"
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                    }

                    // Azioni (solo se con label)
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

                // Altezza in base al contenuto
                implicitHeight: contentCol.implicitHeight + 16

                // Bottone chiusura singola notifica
                ToolButton {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    text: "✕"
                    onClicked: modelData.dismiss()
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
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
            }
        }
    }
}
