import QtQuick
import Quickshell
import Quickshell.Hyprland
import "widgets/"

// Create a proper panel window
Variants {
    id: bar
    model: Quickshell.screens;

    delegate: Component {
        PanelWindow {
            id: panel
            // the screen from the screens list will be injected into this
            // property
            required property var modelData

            // we can then set the window's screen to the injected property
            screen: modelData
        
            
            // Panel configuration - span full width
            anchors {
                top: true
                left: true
                right: true
            }
            
            implicitHeight: 40
            margins {
                top: 0
                left: 0
                right: 0
            }
            
            // The actual bar content - dark mode
            Rectangle {
                id: bar
                anchors.fill: parent
                color: "#1a1a1a"  // Dark background
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

                    // helper to check if a client belongs to a workspace
                    function clientMatchesWorkspace(client, id) {
                        if (!client)
                            return false;
                        if (client.workspace && client.workspace.id !== undefined)
                            return client.workspace.id === id;
                        if (client.workspaceId !== undefined)
                            return client.workspaceId === id;
                        if (client.workspaceID !== undefined)
                            return client.workspaceID === id;
                        if (client.workspace && client.workspace.ID !== undefined)
                            return client.workspace.ID === id;
                        return false;
                    }

                    // return the best icon path for a client if available
                    function clientIcon(client) {
                        if (!client)
                            return "";
                        if (client.icon)
                            return client.icon;
                        if (client.iconPath)
                            return client.iconPath;
                        if (client.appIcon)
                            return client.appIcon;
                        if (client.classIcon)
                            return client.classIcon;
                        return "";
                    }
                    
                    // Real Hyprland workspace data
                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Rectangle {
                            // mostra solo i workspace il cui monitor corrisponde a questo screen
                            visible: modelData.monitor.id === Hyprland.monitorFor(screen).id

                            width: 32
                            height: 24
                            radius: 12
                            color: modelData.active ? "#4a9eff" : "#333333"
                            border.color: "#555555"
                            border.width: 1

                            // id del workspace corrente per filtrare i client
                            property int workspaceId: modelData.id

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }

                            Row {
                                id: workspaceContent
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: workspaceId
                                    color: modelData.active ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 12
                                    font.family: "Inter, sans-serif"
                                }

                                Repeater {
                                    model: Hyprland.clients

                                    delegate: Image {
                                        // show icon only if the client belongs to this workspace
                                        visible: clientMatchesWorkspace(modelData, workspaceId)
                                        width: 14
                                        height: 14
                                        source: clientIcon(modelData)

                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }
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
                        right: timeDisplay.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 0
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
