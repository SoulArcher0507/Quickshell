import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications as NS
import Quickshell.Hyprland

// Popup notifica stile "toast", solo su monitor attivo
Scope {
    id: root

    // *** Usa il server condiviso ***
    required property var server

    // === modello reattivo dei toast (niente array JS) ===
    ListModel { id: toastModel }

    // --- monitor attivo ---
    property var activeScreen: null
    function computeActiveScreen() {
        const fm = Hyprland.focusedMonitor
        const screens = Quickshell.screens
        if (!screens || screens.length === 0) return null
        for (let i = 0; i < screens.length; ++i) {
            const s = screens[i]
            const m = Hyprland.monitorFor(s)
            if (fm && m && m.id === fm.id) return s
        }
        return screens[0]
    }
    Component.onCompleted: activeScreen = computeActiveScreen()
    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onFocusedMonitorChanged() { root.activeScreen = root.computeActiveScreen() }
    }

    // --- hook robusti: tutte le signature note + fallback su tracked ---
    function addToast(n) {
        if (!n) return
        // prova a mantenerla viva, senza rompere su build readonly
        try { n.tracked = true } catch(e) {}
        // evita duplicati
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) return
        toastModel.append({ notif: n })
    }
    function removeToast(n) {
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) { toastModel.remove(i); return }
    }

    Connections {
        target: server
        ignoreUnknownSignals: true
        function onNotification(n)      { addToast(n) }      // alcune build
        function onNotificationAdded(n) { addToast(n) }      // altre build
    }
    Connections {
        target: server && server.trackedNotifications ? server.trackedNotifications : null
        ignoreUnknownSignals: true
        function onValueAdded(key, value) { addToast(value) }
        function onAdded(key, value)      { addToast(value) }
    }

    // === finestra sempre istanziata (niente race), visibile solo quando serve ===
    PanelWindow {
        id: win
        anchors.top: true
        anchors.right: true
        margins.top: 16
        margins.right: 16
        exclusiveZone: 0
        color: "transparent"
        aboveWindows: true
        screen: root.activeScreen ?? (Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0] : null)
        visible: toastModel.count > 0

        implicitWidth: 420
        implicitHeight: column.implicitHeight

        // Colonna di toast
        Column {
            id: column
            anchors.right: parent.right
            spacing: 10

            Repeater {
                id: toastRepeater
                model: toastModel
                delegate: Toast { n: notif; width: 380 } // ruolo diretto del ListModel
            }
        }

        // --- Componente "Toast" singolo ---
        component Toast: Rectangle {
            id: toast
            property var n: null

            radius: 12
            color: "#222222cc"
            border.color: "#00000040"
            border.width: 1
            width: 380

            // Entrata/uscita morbida
            opacity: 0.0; y: 8
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on y       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Component.onCompleted: { opacity = 1.0; y = 0 }

            // Mouse: pausa timer e click = dismiss
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered:  autoClose.running = false
                onExited:   autoClose.running = !!(toast.n) && !(toast.n.resident === true) && (toast.n.expireTimeout !== 0)
                onClicked:  { if (toast.n && typeof toast.n.dismiss === "function") toast.n.dismiss() }
            }

            // Auto-close (expireTimeout è in secondi)
            Timer {
                id: autoClose
                repeat: false
                running: !!(toast.n) && !(toast.n.resident === true) && (toast.n.expireTimeout !== 0)
                interval: (toast.n && typeof toast.n.expireTimeout === "number"
                           ? (toast.n.expireTimeout > 0 ? toast.n.expireTimeout * 1000 : 5000)
                           : 5000)
                onTriggered: if (toast.n && typeof toast.n.expire === "function") toast.n.expire()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Icona / immagine
                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28

                        // 1) Immagine "ricca"
                        IconImage {
                            id: richImage
                            anchors.fill: parent
                            source: (toast.n && toast.n.image) ? toast.n.image : ""
                            visible: source.length > 0
                        }

                        // 2) Fallback: icona di tema
                        QQC2.Button {
                            anchors.fill: parent
                            visible: (!richImage.visible) && !!(toast.n && toast.n.appIcon && toast.n.appIcon.length)
                            enabled: false
                            background: null
                            icon.name: (toast.n && toast.n.appIcon) ? toast.n.appIcon : ""
                            icon.width: 28
                            icon.height: 28
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: (toast.n ? (toast.n.summary || toast.n.appName) : "")
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (toast.n && toast.n.body) ? toast.n.body : ""
                            textFormat: Text.RichText
                            wrapMode: Text.Wrap
                            color: "#dddddd"
                            font.pixelSize: 12
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Indicatore urgenza
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: (toast.n
                            ? (toast.n.urgency === NS.NotificationUrgency.Critical ? "#ff5252"
                               : (toast.n.urgency === NS.NotificationUrgency.Low ? "#7cb342" : "#4a9eff"))
                            : "#4a9eff")
                        Layout.alignment: Qt.AlignTop
                    }
                }

                // Azioni (se presenti)
                Flow {
                    id: actionsFlow
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !!(toast.n && toast.n.actions && toast.n.actions.length > 0)

                    Repeater {
                        model: (toast.n && toast.n.actions) ? toast.n.actions : []
                        delegate: QQC2.Button {
                            required property var modelData
                            text: modelData.text
                            icon.name: (toast.n && toast.n.hasActionIcons) ? modelData.identifier : ""
                            onClicked: modelData.invoke()
                        }
                    }
                }

                // Inline reply (se supportata)
                RowLayout {
                    visible: (!!toast.n && toast.n.hasInlineReply)
                    Layout.fillWidth: true
                    spacing: 8

                    QQC2.TextField {
                        id: replyField
                        Layout.fillWidth: true
                        placeholderText: (toast.n && toast.n.inlineReplyPlaceholder) ? toast.n.inlineReplyPlaceholder : "Rispondi…"
                        onAccepted: sendBtn.clicked()
                    }
                    QQC2.Button {
                        id: sendBtn
                        text: "Invia"
                        enabled: replyField.text.length > 0
                        onClicked: {
                            if (toast.n) {
                                toast.n.sendInlineReply(replyField.text);
                                replyField.clear();
                                if (!toast.n.resident) toast.n.dismiss();
                            }
                        }
                    }
                }
            }

            // Uscita quando il server la chiude + rimozione con piccola animazione
            Connections {
                target: toastModel // ascolta gli oggetti nel modello
                ignoreUnknownSignals: true
            }
        }

        // rimozione post fade
        Timer {
            id: removeLater
            interval: 160; repeat: false
            onTriggered: { /* gestito da onClosed nel delegate */ }
        }
    }
}
