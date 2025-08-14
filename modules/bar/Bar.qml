import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Qt.labs.platform 1.1
import "widgets/"
import org.kde.layershell 1.0

// Create a proper panel window
Variants {
    id: bar
    model: Quickshell.screens;

    readonly property color moduleColor: "#333333"
    readonly property color moduleBorderColor: "#555555"
    readonly property color moduleFontColor: "#cccccc"

    readonly property color workspaceActiveColor: "#4a9eff"
    readonly property color workspaceInactiveColor: moduleColor
    readonly property color workspaceActiveFontColor: "#ffffff"
    readonly property color workspaceInactiveFontColor: moduleFontColor

    delegate: Component {
        Item {
            id: delegateRoot
            required property var modelData

            // ---------------------------
            // Overlay manager con animazioni (senza scrim)
            // ---------------------------
            PanelWindow {
                id: overlayWindow
                screen: delegateRoot.modelData
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                // visibile durante apertura/chiusura o quando è mostrato qualcosa
                visible: (switcher.shownOverlay !== "") || (switcher.pendingIndex !== -1)

                // Click-outside per chiudere (trasparente, nessun oscuramento)
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: switcher.close()
                }

                // Switcher con doppio Loader per cross-fade/scale
                Item {
                    id: switcher
                    anchors.fill: parent
                    z: 1
                    // assicura ESC attivo
                    focus: overlayWindow.visible

                    // Stato e parametri
                    property string shownOverlay: ""     // "", "connection", "notifications", "power"
                    property int    dur: 140
                    property real   scaleIn: 0.98
                    property real   scaleOut: 1.02

                    // Finalizzazione con Timer (chiusura o swap)
                    property int    pendingIndex: -1
                    property string pendingShownOverlay: ""

                    Timer {
                        id: finalizeClose
                        interval: switcher.dur
                        repeat: false
                        onTriggered: {
                            var L = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            L.sourceComponent = null;
                            switcher.shownOverlay = "";
                            switcher.pendingIndex = -1;
                        }
                    }
                    Timer {
                        id: finalizeSwap
                        interval: switcher.dur
                        repeat: false
                        onTriggered: {
                            var outL = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            outL.sourceComponent = null;
                            switcher.activeIndex = (switcher.pendingIndex === 0 ? 1 : 0);
                            switcher.shownOverlay = switcher.pendingShownOverlay;
                            switcher.pendingIndex = -1;
                        }
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape) {
                            switcher.close();
                            event.accepted = true;
                        }
                    }

                    function compFor(which) {
                        return which === "connection" ? connectionComp
                             : which === "notifications" ? notificationsComp
                             : which === "power" ? powerComp
                             : null;
                    }

                    // Doppio loader
                    Loader {
                        id: loaderA
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 1.0
                        scale: 1.0
                        z: 1
                        Behavior on opacity { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                    }
                    Loader {
                        id: loaderB
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 0.0
                        scale: 1.0
                        z: 2
                        Behavior on opacity { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                    }

                    property int activeIndex: 0
                    function currentLoader() { return activeIndex === 0 ? loaderA : loaderB }
                    function otherLoader()   { return activeIndex === 0 ? loaderB : loaderA }

                    // API
                    function open(which) {
                        if (!which) return;
                        var L = currentLoader();
                        L.sourceComponent = compFor(which);
                        L.opacity = 0.0;
                        L.scale = scaleIn;
                        L.opacity = 1.0;
                        L.scale = 1.0;
                        shownOverlay = which;
                    }

                    function close() {
                        if (shownOverlay === "" && pendingIndex === -1) return;
                        var L = currentLoader();
                        L.opacity = 0.0;
                        L.scale = scaleOut;
                        pendingIndex = activeIndex;
                        finalizeClose.start();
                    }

                    function swap(which) {
                        if (!which || which === shownOverlay) return;
                        var outL = currentLoader();
                        var inL  = otherLoader();

                        inL.sourceComponent = compFor(which);
                        inL.opacity = 0.0;
                        inL.scale   = scaleIn;

                        // avvia le animazioni (Behavior fa il resto)
                        outL.opacity = 0.0;
                        outL.scale   = scaleOut;
                        inL.opacity  = 1.0;
                        inL.scale    = 1.0;

                        pendingIndex = activeIndex;
                        pendingShownOverlay = which;
                        finalizeSwap.start();
                    }
                }
            }

            // --------
            // Component caricati on-demand
            // --------
            Component {
                id: connectionComp
                Item {
                    anchors.fill: parent
                    // pannello ancorato in alto a destra
                    Rectangle {
                        id: connectionPanel
                        width: 300
                        height: connectionContent.implicitHeight
                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }
                        // Previeni click-through
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }
                        ConnectionSettings { id: connectionContent; anchors.fill: parent }
                    }
                }
            }

            Component {
                id: notificationsComp
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: notificationPanel
                        width: 300
                        height: notificationContent.implicitHeight
                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }
                        Notifications { id: notificationContent; anchors.fill: parent }
                    }
                }
            }

            Component {
                id: powerComp
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: powerDialog
                        width: 480
                        height: 320
                        radius: 12
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors.centerIn: parent
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Power"
                                color: moduleFontColor
                                font.pixelSize: 16
                                font.family: "Fira Sans Semibold"
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter
                                rows: 2; columns: 3
                                rowSpacing: 12; columnSpacing: 12

                                // Lock
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Lock"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec hyprlock"); } }
                                }
                                // Logout
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Logout"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exit"); } }
                                }
                                // Suspend
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Suspend"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl suspend"); } }
                                }
                                // Hibernate
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Hibernate"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl hibernate"); } }
                                }
                                // Reboot
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Reboot"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl reboot"); } }
                                }
                                // Shutdown
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Shutdown"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl poweroff"); } }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------
            // Pannello principale
            // ----------------
            PanelWindow {
                id: panel
                color: "transparent"
                screen: delegateRoot.modelData

                anchors { top: true; left: true; right: true }
                implicitHeight: 47
                readonly property real scaleFactor: implicitHeight / 45
                margins { top: 0; left: 0; right: 0 }

                Rectangle {
                    id: bar
                    anchors.fill: parent
                    color: "transparent"
                    radius: 0
                    border.color: moduleBorderColor
                    border.width: 0

                    property real barPadding: 16 * panel.scaleFactor

                    Row {
                        id: workspacesRow
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 * panel.scaleFactor }
                        spacing: 8 * panel.scaleFactor

                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                visible: modelData.monitor.id === Hyprland.monitorFor(screen).id
                                width: 30 * panel.scaleFactor
                                height: 30 * panel.scaleFactor
                                radius: 10 * panel.scaleFactor
                                color: modelData.active ? workspaceActiveColor : workspaceInactiveColor
                                border.color: moduleBorderColor
                                border.width: 1 * panel.scaleFactor

                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("workspace " + modelData.id) }

                                Text {
                                    text: modelData.id
                                    anchors.centerIn: parent
                                    color: modelData.active ? workspaceActiveFontColor : workspaceInactiveFontColor
                                    font.pixelSize: 13 * panel.scaleFactor
                                    font.family: "Fira Sans Semibold"
                                }
                            }
                        }

                        Text {
                            visible: Hyprland.workspaces.length === 0
                            text: "No workspaces"
                            color: workspaceActiveFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                        }
                    }

                    // System Tray
                    Rectangle{
                        id: trayButton
                        width: systemTrayWidget.width
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: notifyButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        SystemTray {
                            id: systemTrayWidget
                            bar: panel
                            scaleFactor: panel.scaleFactor
                            anchors { right: notifyButton.left; verticalCenter: parent.verticalCenter; rightMargin: 0 }
                        }
                    }

                    // Notifiche
                    Rectangle {
                        id: notifyButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: rightsidebarButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("notifications");
                                } else if (switcher.shownOverlay === "notifications") {
                                    switcher.close();
                                } else {
                                    switcher.swap("notifications");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    // Right Sidebar Button
                    Rectangle {
                        id: rightsidebarButton
                        width: 70 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: logoutButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        property string networkIcon: ""
                        property string volumeIcon: ""

                        Row {
                            anchors.centerIn: parent
                            spacing: 4 * panel.scaleFactor
                            Text {
                                text: rightsidebarButton.networkIcon + "  " + rightsidebarButton.volumeIcon
                                color: moduleFontColor
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("connection");
                                } else if (switcher.shownOverlay === "connection") {
                                    switcher.close();
                                } else {
                                    switcher.swap("connection");
                                }
                            }
                        }

                        // Nota: nmcliProcess è definito altrove nel tuo progetto
                        Timer { interval: 10000; running: true; repeat: true; onTriggered: nmcliProcess.start() }

                        Connections {
                            target: Pipewire.defaultAudioSink
                            function onVolumeChanged() { rightsidebarButton.updateVolumeIcon() }
                            function onMuteChanged() { rightsidebarButton.updateVolumeIcon() }
                        }

                        Component.onCompleted: { nmcliProcess.start(); updateVolumeIcon() }
                    }

                    // Power
                    Rectangle {
                        id: logoutButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: timeButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("power");
                                } else if (switcher.shownOverlay === "power") {
                                    switcher.close();
                                } else {
                                    switcher.swap("power");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    // Time on the far right
                    Rectangle{
                        id: timeButton
                        width: 147 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 * panel.scaleFactor }

                        Text {
                            id: timeDisplay
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 * panel.scaleFactor }
                            property string currentTime: ""
                            text: currentTime
                            color: moduleFontColor
                            font.pixelSize: 14 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"

                            Timer {
                                interval: 1000; running: true; repeat: true
                                onTriggered: {
                                    var now = new Date()
                                    timeDisplay.currentTime = Qt.formatTime(now, "hh:mm") + " - " + Qt.formatDate(now, "ddd dd MMM")
                                }
                            }

                            Component.onCompleted: {
                                var now = new Date()
                                currentTime = Qt.formatDate(now, "MMM dd") + " " + Qt.formatTime(now, "hh:mm:ss")
                            }
                        }
                    }
                }
            }
        }
    }
}
