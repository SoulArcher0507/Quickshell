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
            // the screen from the screens list will be injected into this
            // property
            required property var modelData

            PanelWindow {
                id: connectionWindow
                screen: delegateRoot.modelData
                anchors {
                    top: true
                    right: true
                }
                margins {
                    right: 16
                }
                width: 300
                height: connectionContent.implicitHeight
                visible: false
                color: "transparent"

                ConnectionSettings {
                    id: connectionContent
                    anchors.fill: parent
                }
            }

            PanelWindow {
                id: notificationWindow
                screen: delegateRoot.modelData
                anchors {
                    top: true
                    right: true
                }
                margins {
                    right: 16
                }
                width: 300
                height: notificationContent.implicitHeight
                visible: false
                color: "transparent"

                Notifications {
                    id: notificationContent
                    anchors.fill: parent
                }
            }

            // --- Power Menu overlay (sostituisce wlogout) ---
            PanelWindow {
                id: powerWindow
                screen: delegateRoot.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                visible: false
                color: "transparent"

                // Contenuto overlay a schermo intero con scrim + dialog
                Item {
                    id: powerRoot
                    anchors.fill: parent
                    focus: powerWindow.visible

                    // Chiudi con ESC
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape) {
                            powerWindow.visible = false
                            event.accepted = true
                        }
                    }

                    // Scrim cliccabile per chiudere
                    Rectangle {
                        id: scrim
                        anchors.fill: parent
                        color: "#00000080"
                        visible: true

                        MouseArea {
                            anchors.fill: parent
                            onClicked: powerWindow.visible = false
                        }
                    }

                    // Dialog centrale
                    Rectangle {
                        id: powerDialog
                        width: 480 * panel.scaleFactor
                        height: 320 * panel.scaleFactor
                        radius: 12 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors.centerIn: parent

                        // Mangia i click per non chiudere il menu
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            onClicked: {} // do nothing, blocca la propagazione
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16 * panel.scaleFactor
                            spacing: 12 * panel.scaleFactor

                            // Titolo
                            Text {
                                text: "Power"
                                color: moduleFontColor
                                font.pixelSize: 16 * panel.scaleFactor
                                font.family: "Fira Sans Semibold"
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Griglia opzioni
                            Grid {
                                id: grid
                                anchors.horizontalCenter: parent.horizontalCenter
                                rows: 2
                                columns: 3
                                rowSpacing: 12 * panel.scaleFactor
                                columnSpacing: 12 * panel.scaleFactor

                                // --- Pulsanti (icone Nerd Font + label Fira Sans) ---
                                // Lock
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Lock"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exec hyprlock")
                                            powerWindow.visible = false
                                        }
                                    }
                                }

                                // Logout (esci da Hyprland)
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Logout"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exit")
                                            powerWindow.visible = false
                                        }
                                    }
                                }

                                // Suspend
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Suspend"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exec systemctl suspend")
                                            powerWindow.visible = false
                                        }
                                    }
                                }

                                // Hibernate
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Hibernate"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exec systemctl hibernate")
                                            powerWindow.visible = false
                                        }
                                    }
                                }

                                // Reboot
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Reboot"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exec systemctl reboot")
                                            powerWindow.visible = false
                                        }
                                    }
                                }

                                // Shutdown
                                Rectangle {
                                    width: 140 * panel.scaleFactor
                                    height: 120 * panel.scaleFactor
                                    radius: 10 * panel.scaleFactor
                                    color: moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1 * panel.scaleFactor

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6 * panel.scaleFactor

                                        Text {
                                            text: ""
                                            font.pixelSize: 34 * panel.scaleFactor
                                            font.family: "CaskaydiaMono Nerd Font"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Shutdown"
                                            font.pixelSize: 13 * panel.scaleFactor
                                            font.family: "Fira Sans Semibold"
                                            color: moduleFontColor
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.dispatch("exec systemctl poweroff")
                                            powerWindow.visible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // --- Fine Power Menu overlay ---

            PanelWindow {
                id: panel
                color: "transparent"
                screen: delegateRoot.modelData

                // Panel configuration - span full width
                anchors {
                    top: true
                    left: true
                    right: true
                }

                // Height of the panel
                implicitHeight: 47

                // Global scale used by widgets inside the bar
                readonly property real scaleFactor: implicitHeight / 45
                margins {
                    top: 0
                    left: 0
                    right: 0
                }

                // The actual bar content - dark mode
                Rectangle {
                    id: bar
                    anchors.fill: parent
                    color: "transparent"
                    radius: 0  // Full width bar without rounded corners
                    border.color: moduleBorderColor
                    border.width: 0

                    // Padding around all modules
                    property real barPadding: 16 * panel.scaleFactor

                    // Row containing all modules
                    Row {
                        id: workspacesRow
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 16 * panel.scaleFactor
                        }
                        spacing: 8 * panel.scaleFactor

                        // Real Hyprland workspace data
                        Repeater {
                            model: Hyprland.workspaces

                            delegate: Rectangle {
                                // mostra solo i workspace il cui monitor corrisponde a questo screen
                                visible: modelData.monitor.id === Hyprland.monitorFor(screen).id

                                width: 30 * panel.scaleFactor
                                height: 30 * panel.scaleFactor
                                radius: 10 * panel.scaleFactor
                                color: modelData.active ? workspaceActiveColor : workspaceInactiveColor
                                border.color: moduleBorderColor
                                border.width: 1 * panel.scaleFactor

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                }

                                Text {
                                    text: modelData.id
                                    anchors.centerIn: parent
                                    color: modelData.active ? workspaceActiveFontColor : workspaceInactiveFontColor
                                    font.pixelSize: 13 * panel.scaleFactor
                                    font.family: "Fira Sans Semibold"
                                }
                            }
                        }

                        // Fallback if no workspaces are detected
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
                        anchors {
                            right: notifyButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }
                        SystemTray {
                            id: systemTrayWidget
                            bar: panel  // Pass the panel window reference
                            scaleFactor: panel.scaleFactor
                            anchors {
                                right: notifyButton.left
                                verticalCenter: parent.verticalCenter
                                rightMargin: 0
                            }
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
                        anchors {
                            right: rightsidebarButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notificationWindow.visible = !notificationWindow.visible
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "" // power icon
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
                        anchors {
                            right: logoutButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

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
                            onClicked: connectionWindow.visible = !connectionWindow.visible
                        }

                        Timer {
                            interval: 10000
                            running: true
                            repeat: true
                            onTriggered: nmcliProcess.start()
                        }

                        Connections {
                            target: Pipewire.defaultAudioSink
                            function onVolumeChanged() { rightsidebarButton.updateVolumeIcon() }
                            function onMuteChanged() { rightsidebarButton.updateVolumeIcon() }
                        }

                        Component.onCompleted: { nmcliProcess.start(); updateVolumeIcon() }
                    }

                    // Button to open Power Menu (al posto di wlogout)
                    Rectangle {
                        id: logoutButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: timeButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerWindow.visible = !powerWindow.visible
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "" // power icon
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    // Time on the far right
                    Rectangle{
                        id: timeButton
                        width: 150 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16 * panel.scaleFactor
                        }
                        Text {
                            id: timeDisplay
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 16 * panel.scaleFactor
                            }

                            property string currentTime: ""

                            text: currentTime
                            color: moduleFontColor
                            font.pixelSize: 14 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"

                            // Update time every second
                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    var now = new Date()
                                    timeDisplay.currentTime = Qt.formatTime(now, "hh:mm") + " - " + Qt.formatDate(now, "ddd dd MMM")
                                }
                            }

                            // Initialize time immediately
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
