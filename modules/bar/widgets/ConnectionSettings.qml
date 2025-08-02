import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
    implicitHeight: content.implicitHeight + margin * 2

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 24

        // Uptime bar
        Row {
            id: uptimeRow
            spacing: 8

            Text {
                text: "\u25B2"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }

            Text {
                text: "Uptime: 7h, 48m"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }
        }

        // Row of buttons/icons
        Row {
            id: iconRow
            spacing: 16
            height: 40

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "\uf1eb"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }
            }

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "\uf293"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }
            }

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "\uf131"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }
            }

            Text {
                text: "\uf24e"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "\uf0e7"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Volume slider
        Row {
            id: volumeRow
            width: parent.width
            spacing: 8

            Text {
                id: volumeIcon
                text: "\uf028"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: volumeSlider
                anchors.verticalCenter: parent.verticalCenter
                width: volumeRow.width - volumeIcon.width - volumeRow.spacing
                from: 0
                to: 100
                value: 50

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 8
                    radius: 4
                    color: "#333333"
                    border.color: "#555555"
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    border.color: "#888888"
                }
            }
        }

        // Brightness slider
        Row {
            id: brightnessRow
            width: parent.width
            spacing: 8

            Text {
                id: brightnessIcon
                text: "\uf185"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: brightnessSlider
                anchors.verticalCenter: parent.verticalCenter
                width: brightnessRow.width - brightnessIcon.width - brightnessRow.spacing
                from: 0
                to: 100
                value: 80

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth
                    height: 8
                    radius: 4
                    color: "#333333"
                    border.color: "#555555"
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    border.color: "#888888"
                }
            }
        }
    }
}

