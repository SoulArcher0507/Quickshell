import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications as NS

// Finestra layer in alto a destra che mostra i "toast"
PanelWindow {
    id: toaster
    color: "transparent"

    // *** Usa il server condiviso ***
    required property var server

    anchors { top: true; right: true }
    margins { top: 16; right: 16 }

    // Mostra la finestra solo se ci sono toast
    visible: toastRepeater.count > 0
    implicitWidth: 420
    implicitHeight: column.implicitHeight

    // Colonna di toast
    Column {
        id: column
        anchors.right: parent.right
        spacing: 10

        Repeater {
            id: toastRepeater
            // ObjectModel/UntypedObjectModel → usa la vista lista "values"
            model: server.trackedNotifications.values
            delegate: Toast { n: modelData; width: 380 }
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

        // Mouse: pausa il timer e clic per dismettere
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered:  autoClose.running = false
            onExited:   autoClose.running = (!!toast.n && !toast.n.resident && toast.n.expireTimeout !== 0)
            onClicked:  { if (toast.n) toast.n.dismiss() }
        }

        // Auto-close: rispetta expireTimeout (in secondi); 0 = non scadere
        Timer {
            id: autoClose
            repeat: false
            running: (!!toast.n && !toast.n.resident && toast.n.expireTimeout !== 0)
            interval: (toast.n
                       ? (toast.n.expireTimeout > 0 ? toast.n.expireTimeout * 1000 : 5000)
                       : 5000)
            onTriggered: if (toast.n) toast.n.expire()
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
                        visible: !richImage.visible && !!(toast.n && toast.n.appIcon && toast.n.appIcon.length)
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

        // Uscita quando il server la chiude
        Connections {
            target: toast.n ? toast.n : null
            function onClosed(reason) {
                toast.opacity = 0.0;
                toast.y = -6;
            }
        }
    }
}
