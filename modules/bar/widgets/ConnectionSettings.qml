import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

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
        RowLayout {
            id: volumeRow
            width: parent.width
            spacing: 8

            Text {
                id: volumeIcon
                text: "\uf028"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                Layout.alignment: Qt.AlignVCenter
            }

            Slider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                from: 0
                to: 100
                value: 50
                onValueChanged: {
                    Pipewire.defaultAudioSink.volume = value / 100
                    Pipewire.defaultAudioSink.mute = (value === 0)
                    updateVolume()
                }

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
        RowLayout {
            id: brightnessRow
            width: parent.width
            spacing: 8

            Text {
                id: brightnessIcon
                text: "\uf185"
                color: "#ffffff"
                font.pixelSize: 16
                font.family: "CaskaydiaMono Nerd Font"
                Layout.alignment: Qt.AlignVCenter
            }

            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                from: 0
                to: 100
                value: 80
                onValueChanged: {
                    Hyprland.dispatch("exec brightnessctl set " + Math.round(value) + "%")
                    updateBrightnessIcon()
                }

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

    function updateVolume() {
        volumeSlider.value = Pipewire.defaultAudioSink.volume * 100
        if (Pipewire.defaultAudioSink.mute || volumeSlider.value === 0) {
            volumeIcon.text = "\uf026"
        } else if (volumeSlider.value < 50) {
            volumeIcon.text = "\uf027"
        } else {
            volumeIcon.text = "\uf028"
        }
    }

    function updateBrightnessIcon() {
        var v = brightnessSlider.value
        if (v < 30) {
            brightnessIcon.text = "\uf186"
        } else if (v < 80) {
            brightnessIcon.text = "\uf185"
        } else {
            brightnessIcon.text = "\uf0eb"
        }
    }

    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { updateVolume() }
        function onMuteChanged() { updateVolume() }
    }

    Component.onCompleted: {
        updateVolume()
        updateBrightnessIcon()
    }
}

