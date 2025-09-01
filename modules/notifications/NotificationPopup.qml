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

    // --- monitor attivo (come prima) ---
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

    Component.onCompleted: {
        activeScreen = computeActiveScreen()
        // segna come viste quelle già tracciate
        try {
            if (server && server.trackedNotifications && server.trackedNotifications.values) {
                for (let n of server.trackedNotifications.values) {
                    if (_seenNotifs.indexOf(n) === -1) _seenNotifs.push(n)
                }
            }
        } catch (e) {}
    }

    Connections { target: Hyprland; ignoreUnknownSignals: true
        function onFocusedMonitorChanged() { root.activeScreen = root.computeActiveScreen() } }
    Connections { target: Quickshell; ignoreUnknownSignals: true
        function onScreensChanged() { root.activeScreen = root.computeActiveScreen() } }

    // --- add/remove toast ---
    function addToast(n) {
        if (!n || BarWidgets.DndState.dnd) return     // blocca creazione in DND
        try { n.tracked = true } catch(e) {}
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) return
        toastModel.append({ notif: n })
    }
    function removeToast(n) {
        for (let i = 0; i < toastModel.count; ++i)
            if (toastModel.get(i).notif === n) { toastModel.remove(i); return }
    }

    // tosta solo se non già vista e DND OFF
    Connections { target: server; ignoreUnknownSignals: true
        function onNotification(n) {
            if (!n) return
            if (BarWidgets.DndState.dnd) return
            if (_seenNotifs.indexOf(n) !== -1) return
            _seenNotifs.push(n)
            addToast(n)
        } }

    // reagisci al cambio DND: se ON, chiudi i toast visibili
    Connections {
        target: BarWidgets.DndState
        function onDndChanged() {
            if (BarWidgets.DndState.dnd) toastModel.clear()
        }
    }

    // (solo rimozioni, niente add)
    Connections { target: server.trackedNotifications; ignoreUnknownSignals: true
        function onObjectRemovedPost(object, index)  { removeToast(object) }
        function onValueRemoved(key, value)          { removeToast(value) }
        function onRemoved(key, value)               { removeToast(value) } }

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
            Component.onCompleted: { opacity = 1.0; y = 0 }

            property bool hovered: false
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function insideInteractive(mouse) {
                    function within(item) {
                        if (!item || !item.visible) return false;
                        var p = item.mapFromItem(toast, mouse.x, mouse.y)
                        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height
                    }
                    return within(replyRow) || within(actionsFlow)
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
                onTriggered: { root.removeToast(toast.n) }
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

                            onClicked: if (modelData && typeof modelData.invoke === "function") modelData.invoke()
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
                        onAccepted: sendBtn.clicked()
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
                function onClosed(reason) { root.removeToast(toast.n) }
                function onTrackedChanged() { if (toast.n && !toast.n.tracked) root.removeToast(toast.n) }
            }
        }
    }
}
