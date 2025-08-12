import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland



Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
    implicitHeight: content.implicitHeight + margin * 2


    Component.onCompleted: {
        const w = QsWindow.window;
        if (w) {
            // Non riservare spazio, stai sopra
            w.aboveWindows = true;              // layer "Top"
            w.exclusiveZone = 0;
            try {
                if (w.WlrLayershell) {
                    w.WlrLayershell.layer = WlrLayer.Overlay; // overlay
                    w.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                }
            } catch (e) {}
            // Tenta di catturare ESC
            // (il focus arriva se il window manager lo concede)
        }
    }
    focus: true
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Escape) {
            const w = QsWindow.window;
            if (w) w.visible = false;
            else root.visible = false;
            event.accepted = true;
        }
    }

    // Clic fuori dalla scheda -> chiudi (funziona se la finestra è più grande della card)
    MouseArea {
        id: clickAway
        anchors.fill: parent
        z: 0
        onClicked: {
            // Clic in "sfondo" (fuori dalla card)
            const local = mapToItem(card, mouse.x, mouse.y);
            if (local.x < 0 || local.y < 0 || local.x > card.width || local.y > card.height) {
                const w = QsWindow.window;
                if (w) w.visible = false;
                else root.visible = false;
            }
        }
    }


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
                id: uptimeText
                text: uptimeString.length > 0 ? `Uptime: ${uptimeString}` : "Uptime: …"
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

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "\uf24e"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "CaskaydiaMono Nerd Font"
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "\uf0e7"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "CaskaydiaMono Nerd Font"
                    anchors.centerIn: parent
                }
            }
        }

        // Volume slider
        RowLayout {
            id: volumeRow
            width: parent.width
            spacing: 8

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter                
                Text {
                    id: volumeIcon
                    text: ""
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "CaskaydiaMono Nerd Font"
                    anchors.centerIn: parent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("exec pavucontrol")
                    }
                }
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
                WheelHandler {
                    onWheel: {
                        const step = 5;
                        volumeSlider.value = Math.min(volumeSlider.to,
                                                     Math.max(volumeSlider.from,
                                                              volumeSlider.value + step * wheel.angleDelta.y / 120))
                    }
                }
            }
        }

        // Brightness slider
        RowLayout {
            id: brightnessRow
            width: parent.width
            spacing: 8

            Rectangle {
                width: 40
                height: 24
                radius: 12
                color: "#333333"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: brightnessIcon
                    text: "\uf185"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "CaskaydiaMono Nerd Font"
                    anchors.centerIn: parent
                }
            }

            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                from: 0
                to: 100
                value: 0
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

                WheelHandler {
                    onWheel: {
                        const step = 5;
                        brightnessSlider.value = Math.min(brightnessSlider.to,
                                                        Math.max(brightnessSlider.from,
                                                                 brightnessSlider.value + step * wheel.angleDelta.y / 120))
                    }
                }
            }
        }
    }

    Timer {
        id: uptimeTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateUptime()
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

    function updateUptime() {
        var proc = Qt.createQmlObject('import Qt.labs.platform 1.1; Process {}', root);
        proc.command = "cat";
        proc.arguments = ["/proc/uptime"];
        proc.start();
        proc.waitForFinished();
        var seconds = parseFloat(proc.readAllStandardOutput().split(" ")[0]);
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        uptimeText.text = "Uptime: " + hours + "h, " + minutes + "m";
    }

    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { updateVolume() }
        function onMuteChanged() { updateVolume() }
    }
    
    // ---- UPTIME ----
    property string uptimeString: ""
    Process {
        id: uptimeProc
        command: ["bash", "-lc", "uptime -p | sed 's/^up //; s/,//g'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.uptimeString = (text || "").trim()
        }
    }
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: uptimeProc.running = true
    }
}

