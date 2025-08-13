import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
    implicitHeight: content.implicitHeight + margin * 2

    // Guard per sync slider <-> sistema
    property bool _syncingVolume: false
    property bool _brightnessInited: false

    Component.onCompleted: {
        const w = QsWindow.window;
        if (w) {
            w.aboveWindows = true;
            w.exclusiveZone = 0;
            try {
                if (w.WlrLayershell) {
                    w.WlrLayershell.layer = WlrLayer.Overlay;
                    w.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                }
            } catch (e) {}
        }
        // Sync iniziale
        syncVolumeFromSystem()
        brightnessReadProc.running = true
    }

    focus: true
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Escape) {
            const w = QsWindow.window;
            if (w) w.visible = false; else root.visible = false;
            event.accepted = true;
        }
    }

    // Click fuori -> chiudi
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: {
            const local = mapToItem(content, mouse.x, mouse.y);
            if (local.x < 0 || local.y < 0 || local.x > content.width || local.y > content.height) {
                const w = QsWindow.window;
                if (w) w.visible = false; else root.visible = false;
            }
        }
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 24

        // Uptime
        Row {
            spacing: 8
            Text {
                id: uptimeText
                text: uptimeString.length > 0 ? `Uptime: ${uptimeString}` : "Uptime: …"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }
        }

        // Prima barra: Wi-Fi, Bluetooth, Profili alimentazione
        RowLayout {
            id: iconRow
            width: parent.width
            spacing: 16

            // Wi-Fi
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                radius: 12
                color: "#333333"
                Text {
                    anchors.centerIn: parent
                    text: "\uf1eb"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }
            }

            // Bluetooth
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                radius: 12
                color: "#333333"
                Text {
                    anchors.centerIn: parent
                    text: "\uf293"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Profili energia (icone a pill, gruppo esclusivo)
            Rectangle {
                id: powerProfilesGroup
                Layout.preferredHeight: 24
                Layout.preferredWidth: segmentCount * segmentWidth + segmentSpacing * (segmentCount - 1)
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                color: "transparent"
                border.width: 0
                antialiasing: true

                property color baseFill:   "#333333"
                property color iconColor:  "#ffffff"
                property color accent:     "#4a9eff"
                property int  radiusPx:    12

                property int segmentCount: 3
                property int segmentWidth: 40
                property int segmentSpacing: 8
                readonly property var pp: PowerProfiles

                readonly property var segments: [
                    { key: PowerProfile.PowerSaver,  icon: "\uf06c",  requiresPerf: false }, // leaf
                    { key: PowerProfile.Balanced,    icon: "\uf24e",  requiresPerf: false }, // balance-scale
                    { key: PowerProfile.Performance, icon: "\uf135",  requiresPerf: true  }  // rocket
                ]

                Row {
                    anchors.fill: parent
                    spacing: powerProfilesGroup.segmentSpacing

                    Repeater {
                        model: powerProfilesGroup.segments

                        delegate: Rectangle {
                            id: seg
                            width: powerProfilesGroup.segmentWidth
                            height: powerProfilesGroup.height
                            radius: powerProfilesGroup.radiusPx
                            color: powerProfilesGroup.baseFill
                            border.width: (powerProfilesGroup.pp.profile === modelData.key) ? 2 : 0
                            border.color: powerProfilesGroup.accent
                            antialiasing: true

                            readonly property bool disabledBtn:
                                (modelData.requiresPerf && !powerProfilesGroup.pp.hasPerformanceProfile)
                            opacity: disabledBtn ? 0.5 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: powerProfilesGroup.iconColor
                                font.pixelSize: 14
                                font.family: "CaskaydiaMono Nerd Font"
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !seg.disabledBtn
                                hoverEnabled: true
                                onClicked: powerProfilesGroup.pp.profile = modelData.key
                            }
                        }
                    }
                }
            }
        }

        // SLIDER 1 — VOLUME (icona sinistra, slider destra)
        RowLayout {
            id: volumeRow
            width: parent.width
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: "#333333"
                Text {
                    id: volumeIcon
                    text: "\uf027" // default low
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
                    if (root._syncingVolume) return
                    // Imposta volume via wpctl (PipeWire)
                    const v = Math.round(value)
                    Hyprland.dispatch("exec wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (v/100).toFixed(2))
                    Hyprland.dispatch("exec wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (v === 0 ? "1" : "0"))
                    updateVolumeIconFrom(v, v === 0)
                    volDebounceRead.restart()
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
                        volumeSlider.value = Math.min(
                            volumeSlider.to,
                            Math.max(volumeSlider.from,
                                     volumeSlider.value + step * wheel.angleDelta.y / 120)
                        )
                    }
                }
            }
        }

        // SLIDER 2 — LUMINOSITÀ (icona sinistra, slider destra)
        RowLayout {
            id: brightnessRow
            width: parent.width
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: "#333333"
                Text {
                    id: brightnessIcon
                    text: "\uf185" // sun
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
                    if (!root._brightnessInited) return
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
                        brightnessSlider.value = Math.min(
                            brightnessSlider.to,
                            Math.max(brightnessSlider.from,
                                     brightnessSlider.value + step * wheel.angleDelta.y / 120)
                        )
                    }
                }
            }
        }
    }

    // ====== VOLUME: lettura/sync con il sistema ======
    function updateVolumeIconFrom(v, muted) {
        if (muted || v === 0) {
            volumeIcon.text = "\uf026" // mute
        } else if (v < 50) {
            volumeIcon.text = "\uf027" // low
        } else {
            volumeIcon.text = "\uf028" // high
        }
    }

    function parseWpctlVolume(out) {
        // Esempio: "Volume: 0.45 [MUTED]" oppure "Volume: 1.00"
        const s = (out || "").trim()
        const m = s.match(/([0-9.]+)/)
        const vol = m ? Math.round(parseFloat(m[1]) * 100) : null
        const muted = s.indexOf("MUTED") !== -1
        return { vol: vol, muted: muted }
    }

    function syncVolumeFromSystem() {
        // Se disponibile PipeWire, usa quello; altrimenti fallback su wpctl
        if (Pipewire.defaultAudioSink && !isNaN(Pipewire.defaultAudioSink.volume)) {
            _syncingVolume = true
            const v = Math.round(Pipewire.defaultAudioSink.volume * 100)
            const muted = Pipewire.defaultAudioSink.mute === true || v === 0
            volumeSlider.value = v
            updateVolumeIconFrom(v, muted)
            _syncingVolume = false
        } else {
            volReadProc.running = true
        }
    }

    Process {
        id: volReadProc
        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const r = parseWpctlVolume(text)
                if (r.vol !== null) {
                    root._syncingVolume = true
                    volumeSlider.value = r.vol
                    updateVolumeIconFrom(r.vol, r.muted)
                    root._syncingVolume = false
                }
            }
        }
    }

    // Poll leggero per restare aggiornati anche se cambi da mixer esterni
    Timer {
        id: volPoll
        interval: 1500
        running: true
        repeat: true
        onTriggered: volReadProc.running = true
    }
    // Debounce dopo intervento manuale
    Timer {
        id: volDebounceRead
        interval: 300
        repeat: false
        onTriggered: volReadProc.running = true
    }

    // Se PipeWire emette eventi, usali comunque
    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { syncVolumeFromSystem() }
        function onMuteChanged()   { syncVolumeFromSystem() }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { syncVolumeFromSystem() }
    }

    // ====== LUMINOSITÀ: lettura iniziale e icone ======
    Process {
        id: brightnessReadProc
        command: ["bash", "-lc", "c=$(brightnessctl g 2>/dev/null); m=$(brightnessctl m 2>/dev/null); if [ -n \"$c\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then printf '%d\n' $(( 100 * c / m )); else echo -1; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim()
                const p = parseInt(t, 10)
                root._brightnessInited = true
                brightnessSlider.value = (!isNaN(p) && p >= 0) ? p : 50
                updateBrightnessIcon()
            }
        }
    }

    function updateBrightnessIcon() {
        var v = brightnessSlider.value
        if (v < 30) {
            brightnessIcon.text = "\uf186" // moon
        } else if (v < 80) {
            brightnessIcon.text = "\uf185" // sun
        } else {
            brightnessIcon.text = "\uf0eb" // lightbulb
        }
    }

    // ====== UPTIME ======
    Timer {
        id: uptimeTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateUptime()
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

    // Uptime string da `uptime -p`
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
