import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Services.SystemTray

// System tray widget that displays system tray icons
Item {
    id: systemTrayWidget

    // Required property for the bar window reference
    required property var bar
    // Scale factor to size the tray items
    property real scaleFactor: 1.0

    // Dark theme colors matching the bar theme
    readonly property color surfaceVariant: "#333333"
    readonly property color accentPrimary: "#4a9eff"
    readonly property color textPrimary: "#ffffff"
    readonly property color backgroundPrimary: "#1a1a1a"

    readonly property int baseIconSize: 22
    readonly property int baseIconSpacing: 8
    readonly property int baseIconPadding: 4

    readonly property int iconSize: baseIconSize * scaleFactor
    readonly property int iconSpacing: baseIconSpacing * scaleFactor
    readonly property int iconPadding: baseIconPadding * scaleFactor

    // Calculate width based on number of tray items
    width: Math.max(0, trayRow.children.length * (iconSize + iconSpacing) - iconSpacing)

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

                // --- anchor point (in window coords) calcolato al click ---
                property real _anchorX: 0
                property real _anchorY: 0

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        trayItem.activate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (trayItem.hasMenu) {
                            // 1) prendi la posizione globale del click
                            const gx = mouse.screenX
                            const gy = mouse.screenY
                            // 2) rimappa alle coordinate della finestra del pannello
                            const w = QsWindow.window
                            if (w && w.mapFromGlobal) {
                                const pt = w.mapFromGlobal(gx, gy)
                                trayMouseArea._anchorX = pt.x
                                trayMouseArea._anchorY = pt.y
                            } else {
                                // fallback: mappa l'angolo del MouseArea nella finestra
                                const p = trayMouseArea.mapToItem(w ? w.contentItem : null, 0, 0)
                                trayMouseArea._anchorX = p.x + trayMouseArea.width / 2
                                trayMouseArea._anchorY = p.y + trayMouseArea.height
                            }
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
                    // Usa la vera finestra del pannello
                    anchor.window: QsWindow.window

                    // Allinea il menu al punto di click (sotto l'icona)
                    // Nota: coordinate già in spazio della finestra
                    anchor.rect.x: trayMouseArea._anchorX - trayMouseArea.width / 2
                    anchor.rect.y: trayMouseArea._anchorY
                    anchor.rect.width: trayMouseArea.width
                    anchor.rect.height: trayMouseArea.height

                    // Apri VERSO IL BASSO dal punto di ancoraggio
                    anchor.edges: Edges.Top
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
                    width: iconSize - 2
                    height: iconSize - 2
                    source: trayItem.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true

                    // Fallback text if icon fails to load
                    Text {
                        anchors.centerIn: parent
                        text: trayItem.title ? trayItem.title.charAt(0).toUpperCase() : "?"
                        color: textPrimary
                        font.pixelSize: 12 * scaleFactor
                        font.bold: true
                        visible: parent.status === Image.Error || parent.status === Image.Null
                    }
                }

                // --- Tooltip custom che non copre il mouse (FIX visibilità) ---
                Item {
                    id: hoverTip
                    // ospite: contentItem della finestra, fallback al widget
                    property var hostItem: QsWindow.window && QsWindow.window.contentItem
                                           ? QsWindow.window.contentItem
                                           : systemTrayWidget

                    // disegna sopra tutto, non intercetta input
                    z: 9999
                    visible: trayMouseArea.containsMouse && trayItem.title && trayItem.title.length > 0
                    parent: hostItem

                    // offset per non coprire il cursore
                    property int dx: Math.round(12 * systemTrayWidget.scaleFactor)
                    property int dy: Math.round(18 * systemTrayWidget.scaleFactor)

                    // punto del mouse rimappato nello spazio dell'host
                    property var pt: trayMouseArea.mapToItem(hostItem, trayMouseArea.mouseX, trayMouseArea.mouseY)

                    // padding e dimensioni
                    property int pad: Math.round(6 * systemTrayWidget.scaleFactor)
                    readonly property int tipW: tipText.implicitWidth + 2*pad
                    readonly property int tipH: tipText.implicitHeight + 2*pad

                    width: tipW
                    height: tipH

                    // clamp dentro l'host
                    x: Math.min(Math.max(pt.x + dx, 0), hostItem.width  - width)
                    y: Math.min(Math.max(pt.y + dy, 0), hostItem.height - height)

                    // piccolo fade-in
                    opacity: 1.0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: systemTrayWidget.backgroundPrimary
                        border.width: 1
                        border.color: systemTrayWidget.surfaceVariant
                        opacity: 0.95

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: trayItem.title
                            color: systemTrayWidget.textPrimary
                            font.pixelSize: Math.round(12 * systemTrayWidget.scaleFactor)
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
}
