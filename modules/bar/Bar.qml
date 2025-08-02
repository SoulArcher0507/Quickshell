import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Qt.labs.platform 1.1
import "widgets/"
import org.kde.layershell 1.0

// Create a proper panel window
Variants {
    id: bar
    model: Quickshell.screens;

    
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
                    bottom: true
                    right: true
                }
                width: 300
                visible: false
                color: "#222222"

                ConnectionSettings {
                    anchors.fill: parent
                }
            }

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
                    border.color: "#333333"
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
                                color: modelData.active ? "#4a9eff" : "#333333"
                                border.color: "#555555"
                                border.width: 1 * panel.scaleFactor

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                }

                                Text {
                                    text: modelData.id
                                    anchors.centerIn: parent
                                    color: modelData.active ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 12 * panel.scaleFactor
                                    font.family: "CaskaydiaMono Nerd Font"
                                }
                            }
                        }

                        // Fallback if no workspaces are detected
                        Text {
                            visible: Hyprland.workspaces.length === 0
                            text: "No workspaces"
                            color: "#ffffff"
                            font.pixelSize: 12 * panel.scaleFactor
                        }
                    }

                    Rectangle{
                        id: trayButton
                        width: systemTrayWidget.width
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: "#333333"
                        border.color: "#555555"
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: networkButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }
                        SystemTray {
                            id: systemTrayWidget
                            bar: panel  // Pass the panel window reference
                            scaleFactor: panel.scaleFactor
                            anchors {
                                right: networkButton.left
                                verticalCenter: parent.verticalCenter
                                rightMargin: 0
                            }
                        }
                    }


                    Rectangle {
                        id: networkButton
                        width: 55 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: "#333333"
                        border.color: "#555555"
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: logoutButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        property bool isEthernet: true
                        property string networkIcon: isEthernet ? "" : ""

                        Row {
                            anchors.centerIn: parent
                            spacing: 4 * panel.scaleFactor

                            Text {
                                text: networkButton.networkIcon + "  "
                                color: "#cccccc"
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: connectionWindow.visible = !connectionWindow.visible
                        }



                        Timer {
                            interval: 10000
                            running: true
                            repeat: true
                            onTriggered: nmcliProcess.start()
                        }

                        Component.onCompleted: nmcliProcess.start()
                    }

                    // Button to trigger wlogout between tray and clock
                    Rectangle {
                        id: logoutButton
                        width: 30 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: "#333333"
                        border.color: "#555555"
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: timeButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16 * panel.scaleFactor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("exec ~/.config/hypr/scripts/wlogout.sh")
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "" // power icon
                            color: "#cccccc"
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"
                        }
                    }

                    // Time on the far right
                    Rectangle{
                        id: timeButton
                        width: 180 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: "#333333"
                        border.color: "#555555"
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
                            color: "#ffffff"
                            font.pixelSize: 14 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"

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
