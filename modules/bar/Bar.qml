import QtQuick
import Quickshell
import Quickshell.Hyprland
import "widgets/"
import LayerShellQt 1.0

// Create a proper panel window
Variants {
    id: bar
    model: Quickshell.screens;

    delegate: Component {
        PanelWindow {
            id: panel
            color: "transparent"
            // the screen from the screens list will be injected into this
            // property
            required property var modelData

            // we can then set the window's screen to the injected property
            screen: modelData

            LayerSurface {
                anchors.fill: parent
                window: panel
                layer: LayerSurface.LayerTop
                scope: "panel"
            }
        
            
            // Panel configuration - span full width
            anchors {
                top: true
                left: true
                right: true
            }
            
            implicitHeight: 45
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
                border.width: 1

                // Workspaces on the far left - connected to Hyprland
                Row {
                    id: workspacesRow
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 16
                    }
                    spacing: 8
                    
                    // Real Hyprland workspace data
                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Rectangle {
                            // mostra solo i workspace il cui monitor corrisponde a questo screen
                            visible: modelData.monitor.id === Hyprland.monitorFor(screen).id

                            width: 30
                            height: 24
                            radius: 8
                            color: modelData.active ? "#4a9eff" : "#333333"
                            border.color: "#555555"
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }

                            Text {
                                text: modelData.id
                                anchors.centerIn: parent
                                color: modelData.active ? "#ffffff" : "#cccccc"
                                font.pixelSize: 12
                                font.family: "Inter, sans-serif"
                            }
                        }
                    }
                    
                    // Fallback if no workspaces are detected
                    Text {
                        visible: Hyprland.workspaces.length === 0
                        text: "No workspaces"
                        color: "#ffffff"
                        font.pixelSize: 12
                    }
                }


                SystemTray {
                    id: systemTrayWidget
                    bar: panel  // Pass the panel window reference
                    anchors {
                        right: logoutButton.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 0
                    }
                }

                // Button to trigger wlogout between tray and clock
                Rectangle {
                    id: logoutButton
                    width: 30
                    height: 24
                    radius: 10
                    color: "#333333"
                    border.color: "#555555"
                    border.width: 1
                    anchors {
                        right: timeDisplay.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("exec ~/.config/hypr/scripts/wlogout.sh")
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "" // power icon
                        color: "#cccccc"
                        font.pixelSize: 12
                        font.family: "Inter, fira-sans-semibold"
                    }
                }

                // Time on the far right
                Text {
                    id: timeDisplay
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 16
                    }
                    
                    property string currentTime: ""
                    
                    text: currentTime
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "Inter, sans-serif"
                    
                    // Update time every second
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            var now = new Date()
                            timeDisplay.currentTime = Qt.formatDate(now, "ddd dd MMM") + " " + Qt.formatTime(now, "hh:mm:ss")
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