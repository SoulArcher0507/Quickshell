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

    // Ancorata al bordo alto-destro
    anchors {
        top: true
        right: true
    }
    margins {
        top: 16
        right: 16
    }

    // Mostra la finestra solo se ci sono toast
    visible: toastRepeater.count > 0
    implicitWidth: 420
    implicitHeight: column.implicitHeight

    // --- Notification server (unico, DBus) ---
    NS.NotificationServer {
        id: server

        // Pubblicizza le capacità del server
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true

        // Traccia le notifiche in arrivo (così compaiono a schermo)
        onNotification: function(n) { n.tracked = true; }
    }

    // Colonna di toast
    Column {
        id: column
        anchors.right: parent.right
        spacing: 10

        Repeater {
            id: toastRepeater
            // PRIMA: model: server.trackedNotifications
            model: server.trackedNotifications.values
            delegate: Toast { n: modelData; width: 380 }
        }
    }

    // --- Componente "Toast" singolo ---
    component Toast: Rectangle {
        id: toast
        required property var n  // NS.Notification

        radius: 12
        color: "#222222cc"
        border.color: "#00000040"
        border.width: 1
        width: 380

        // Entrata/uscita morbida
        opacity: 0.0
        y: 8
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on y       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Component.onCompleted: {
            opacity = 1.0;
            y = 0;
        }

        // Mouse: pausa il timer e clic per dismettere
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: autoClose.running = false
            onExited:  if (!n.resident) autoClose.running = true
            onClicked: n.dismiss()
        }

        // Auto-close (fallback se l'app non imposta expireTimeout)
        Timer {
            id: autoClose
            repeat: false
            // parte solo se non è resident e se non è stato chiesto timeout infinito (0)
            running: n && !n.resident && n.expireTimeout !== 0
            interval: (n && n.expireTimeout > 0 ? n.expireTimeout * 1000 : 5000)
            onTriggered: n.expire()
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

                    // 1) Immagine "ricca" della notifica (es. avatar)
                    IconImage {
                        id: richImage
                        anchors.fill: parent
                        // IconImage è un wrapper di Image: usa "source"
                        // Qui funziona con URL/percorsi reali (n.image può esserlo)
                        source: (n.image && n.image.length) ? n.image : ""
                        visible: source.length > 0
                    }

                    // 2) Fallback: icona di tema (per nome) usando un controllo QQC2
                    // (Image non risolve i nomi di tema; un Button sì tramite icon.name)
                    QQC2.Button {
                        anchors.fill: parent
                        visible: !richImage.visible && (n.appIcon && n.appIcon.length)
                        enabled: false
                        background: null
                        icon.name: n.appIcon
                        // forza dimensione dell'icona
                        icon.width: 28
                        icon.height: 28
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: n.summary || n.appName
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: n.body
                        textFormat: Text.RichText   // markup/hyperlink support
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
                    color: n.urgency === NS.NotificationUrgency.Critical ? "#ff5252"
                          : (n.urgency === NS.NotificationUrgency.Low ? "#7cb342" : "#4a9eff")
                    Layout.alignment: Qt.AlignTop
                }
            }

            // Azioni (se presenti)
            Flow {
                id: actionsFlow
                Layout.fillWidth: true
                spacing: 8
                visible: n.actions.length > 0

                Repeater {
                    model: n.actions
                    delegate: QQC2.Button {
                        text: modelData.text
                        icon.name: n.hasActionIcons ? modelData.identifier : ""
                        onClicked: modelData.invoke()
                    }
                }
            }

            // Inline reply (se supportata)
            RowLayout {
                visible: n.hasInlineReply
                Layout.fillWidth: true
                spacing: 8

                QQC2.TextField {
                    id: replyField
                    Layout.fillWidth: true
                    placeholderText: n.inlineReplyPlaceholder || "Rispondi…"
                    onAccepted: sendBtn.clicked()
                }
                QQC2.Button {
                    id: sendBtn
                    text: "Invia"
                    enabled: replyField.text.length > 0
                    onClicked: {
                        n.sendInlineReply(replyField.text);
                        replyField.clear();
                        if (!n.resident) n.dismiss();
                    }
                }
            }
        }

        // Anima l'uscita quando viene chiusa da remoto
        Connections {
            target: n
            enabled: !!n
            function onClosed(reason) {
                toast.opacity = 0.0;
                toast.y = -6;
            }
        }
    }
}
