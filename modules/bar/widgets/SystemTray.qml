import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// System tray widget that displays system tray icons
Item {
    id: systemTrayWidget
    
    // Required property for the bar window reference
    required property var bar
    
    // Dark theme colors matching the bar theme
    readonly property color surfaceVariant: "#333333"
    readonly property color accentPrimary: "#4a9eff"
    readonly property color textPrimary: "#ffffff"
    readonly property color backgroundPrimary: "#1a1a1a"
    
    readonly property int iconSize: 22
    readonly property int iconSpacing: 8
    readonly property int iconPadding: 4
    
    // Calculate width based on number of tray items
    width: Math.max(0, trayRow.children.length * (iconSize + iconSpacing) - iconSpacing)
    height: iconSize + iconPadding * 2
    
    // Row to hold all system tray icons
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: iconSpacing
        
        Repeater {
            model: SystemTray.items
            
            // Individual system tray icon
            MouseArea {
                id: trayMouseArea
                
                property SystemTrayItem trayItem: modelData
                
                width: iconSize
                height: iconSize
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        trayItem.activate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (trayItem.hasMenu) {
                            menuAnchor.open()
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItem.secondaryActivate()
                    }
                }
                
                onWheel: function(wheel) {
                    trayItem.scroll(wheel.angleDelta.x, wheel.angleDelta.y)
                }
                
                // Context menu anchor
                QsMenuAnchor {
                    id: menuAnchor
                    
                    menu: trayItem.menu
                    anchor.window: systemTrayWidget.bar
                    anchor.rect.x: trayMouseArea.x + systemTrayWidget.x
                    anchor.rect.y: trayMouseArea.y + systemTrayWidget.y
                    anchor.rect.width: trayMouseArea.width
                    anchor.rect.height: trayMouseArea.height
                    anchor.edges: Edges.Bottom
                }
                
                // Background rectangle with hover effect
                Rectangle {
                    id: backgroundRect
                    anchors.fill: parent
                    color: trayMouseArea.containsMouse ? surfaceVariant : "transparent"
                    radius: 4
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                
                // Icon image
                Image {
                    id: iconImage
                    anchors.centerIn: parent
                    width: iconSize - 4
                    height: iconSize - 4
                    source: trayItem.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    
                    // Fallback text if icon fails to load
                    Text {
                        anchors.centerIn: parent
                        text: trayItem.title ? trayItem.title.charAt(0).toUpperCase() : "?"
                        color: textPrimary
                        font.pixelSize: 12
                        font.bold: true
                        visible: parent.status === Image.Error || parent.status === Image.Null
                    }
                }
                
                // Tooltip
                Rectangle {
                    id: tooltip
                    visible: trayMouseArea.containsMouse && trayItem.title && trayItem.title.length > 0
                    color: backgroundPrimary
                    border.color: surfaceVariant
                    border.width: 1
                    radius: 6
                    width: tooltipText.width + 16
                    height: tooltipText.height + 12
                    
                    // Position tooltip above the icon
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 8
                    
                    Text {
                        id: tooltipText
                        anchors.centerIn: parent
                        text: trayItem.title || ""
                        color: textPrimary
                        font.pixelSize: 11
                    }
                    
                    // Fade in/out animation
                    opacity: trayMouseArea.containsMouse ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
    
    // Show a placeholder when no system tray items are available
    Text {
        anchors.centerIn: parent
        visible: SystemTray.items.length === 0
        text: "No tray items"
        color: surfaceVariant
        font.pixelSize: 10
        font.family: "Inter, sans-serif"
        opacity: 0.7
    }
} 