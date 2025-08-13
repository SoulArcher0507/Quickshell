import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth

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

    // ====== RETE: stato e misure ======
    // tipo: "ethernet" | "wifi" | "down" | "unknown"
    property string netType: "unknown"
    property string netIface: ""
    property string netName: ""
    property string netIp4: ""
    property real   _lastRxBytes: 0
    property real   _lastTxBytes: 0
    property real   _lastNetTms:  0
    property real   rxBps: 0
    property real   txBps: 0

    function _humanBitsPerSec(bps) {
        var u = ["b/s","Kb/s","Mb/s","Gb/s","Tb/s"];
        var val = bps;
        var i = 0;
        while (val >= 1000 && i < u.length - 1) { val /= 1000; i++; }
        return (val >= 100 ? Math.round(val) : Math.round(val*10)/10) + " " + u[i];
    }

    function _updateTooltipText() {
        if (netType === "down") return "Nessuna connessione";
        var t = (netType === "ethernet") ? "Ethernet" : (netType === "wifi" ? "Wi-Fi" : "Rete");
        var name = (netName && netName.length) ? netName : "(sconosciuta)";
        var ip = (netIp4 && netIp4.length) ? netIp4 : "—";
        var down = _humanBitsPerSec(rxBps);
        var up   = _humanBitsPerSec(txBps);
        return t + ": " + name +
               "\nInterfaccia: " + netIface +
               "\nIP: " + ip +
               "\n↓ " + down + "   ↑ " + up;
    }

    function _pickIconForNet() {
        // Emoji/Unicode compatibili con Fira Sans (fallback automatico a Noto Emoji)
        if (netType === "ethernet") return ""; // wired network
        if (netType === "wifi")     return ""; // bars
        return "";                 // no network
    }


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
        syncVolumeFromSystem();
        brightnessReadProc.running = true;

        // rete init
        netInfoProc.running = true;
    }

    focus: true
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape) {
            const w = QsWindow.window;
            if (w) w.visible = false; else root.visible = false;
            event.accepted = true;
        }
    }

    // Click fuori -> chiudi (fix handler param)
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: function(mouse) {
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
                text: (uptimeString.length > 0) ? ("Uptime: " + uptimeString) : "Uptime: …"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }
        }

        // Prima barra: Rete, Bluetooth, Profili alimentazione
        RowLayout {
            id: iconRow
            width: parent.width
            spacing: 16

            // ===== Rete =====
            Rectangle {
                id: netButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                radius: 12
                color: (netType === "down" || netType === "unknown") ? "#333333" : "#3a6fb3"

                Text {
                    id: netIcon
                    anchors.centerIn: parent
                    text: _pickIconForNet()
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "Fira Sans Semibold"
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: netArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function() {
                        // iwgtk -> nm-connection-editor -> nmtui su primo terminale trovato
                        Hyprland.dispatch(
                            "exec bash -lc '" +
                            "if command -v iwgtk >/dev/null 2>&1; then exec iwgtk; " +
                            "elif command -v nm-connection-editor >/dev/null 2>&1; then exec nm-connection-editor; " +
                            "else " +
                              "(command -v alacritty >/dev/null 2>&1 && exec alacritty -e nmtui) || " +
                              "(command -v kitty >/dev/null 2>&1 && exec kitty nmtui) || " +
                              "(command -v foot >/dev/null 2>&1 && exec foot -e nmtui) || " +
                              "(command -v wezterm >/dev/null 2>&1 && exec wezterm start -- nmtui) || " +
                              "(command -v gnome-terminal >/dev/null 2>&1 && exec gnome-terminal -- nmtui) || " +
                              "(command -v xterm >/dev/null 2>&1 && exec xterm -e nmtui) || " +
                              "exec nmtui; fi'"
                        );
                    }
                }

                ToolTip {
                    visible: netArea.containsMouse
                    delay: 250
                    text: _updateTooltipText()
                }
            }

            // ===== Bluetooth — apre il manager al click =====
            Rectangle {
                id: btButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                radius: 12
                color: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? "#3a6fb3" : "#333333"

                Text {
                    anchors.centerIn: parent
                    text: "\uf293"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: "CaskaydiaMono Nerd Font"
                }

                MouseArea {
                    id: btArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function() {
                        Hyprland.dispatch("exec blueman-manager");
                    }
                }

                ToolTip {
                    visible: btArea.containsMouse
                    delay: 250
                    text: {
                        if (!Bluetooth.defaultAdapter) return "Bluetooth non disponibile";
                        let names = [];
                        try {
                            const n = Bluetooth.devices ? Bluetooth.devices.count : 0;
                            for (let i = 0; i < n; ++i) {
                                const d = Bluetooth.devices.get(i);
                                if (d && d.connected) names.push(d.name || d.deviceName || d.address);
                            }
                        } catch(e) {}
                        return names.length ? names.join(", ") : "Nessun dispositivo connesso";
                    }
                }
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Profili energia (come da tuo file)
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
                    { key: PowerProfile.PowerSaver,  icon: "\uf06c",  requiresPerf: false },
                    { key: PowerProfile.Balanced,    icon: "\uf24e",  requiresPerf: false },
                    { key: PowerProfile.Performance, icon: "\uf135",  requiresPerf: true  }
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
                                onClicked: function() { powerProfilesGroup.pp.profile = modelData.key; }
                            }
                        }
                    }
                }
            }
        }

        // SLIDER 1 — VOLUME
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
                    text: "\uf027"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "CaskaydiaMono Nerd Font"
                    anchors.centerIn: parent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() { Hyprland.dispatch("exec pavucontrol"); }
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
                    if (root._syncingVolume) return;
                    const v = Math.round(value);

                    if (Pipewire.defaultAudioSink && !isNaN(Pipewire.defaultAudioSink.volume)) {
                        Pipewire.defaultAudioSink.volume = v / 100.0;
                        Pipewire.defaultAudioSink.mute   = (v === 0);
                    } else {
                        Hyprland.dispatch("exec wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (v/100).toFixed(2));
                        Hyprland.dispatch("exec wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (v === 0 ? "1" : "0"));
                    }

                    updateVolumeIconFrom(v, v === 0);
                    volDebounceRead.restart();
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
                    onWheel: function(e) {
                        const step = 5;
                        volumeSlider.value = Math.min(
                            volumeSlider.to,
                            Math.max(volumeSlider.from,
                                     volumeSlider.value + step * e.angleDelta.y / 120)
                        );
                    }
                }
            }
        }

        // SLIDER 2 — LUMINOSITÀ
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
                    if (!root._brightnessInited) return;
                    Hyprland.dispatch("exec brightnessctl set " + Math.round(value) + "%");
                    updateBrightnessIcon();
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
                    onWheel: function(e) {
                        const step = 5;
                        brightnessSlider.value = Math.min(
                            brightnessSlider.to,
                            Math.max(brightnessSlider.from,
                                     brightnessSlider.value + step * e.angleDelta.y / 120)
                        );
                    }
                }
            }
        }
    }

    // ====== VOLUME: lettura/sync con il sistema ======
    function updateVolumeIconFrom(v, muted) {
        if (muted || v === 0) {
            volumeIcon.text = "\uf026";
        } else if (v < 50) {
            volumeIcon.text = "\uf027";
        } else {
            volumeIcon.text = "\uf028";
        }
    }

    function parseWpctlVolume(out) {
        const s = (out || "").trim();
        const m = s.match(/([0-9.]+)/);
        const vol = m ? Math.round(parseFloat(m[1]) * 100) : null;
        const muted = s.indexOf("MUTED") !== -1;
        return { vol: vol, muted: muted };
    }

    function syncVolumeFromSystem() {
        if (Pipewire.defaultAudioSink && !isNaN(Pipewire.defaultAudioSink.volume)) {
            _syncingVolume = true;
            const v = Math.round(Pipewire.defaultAudioSink.volume * 100);
            const muted = Pipewire.defaultAudioSink.mute === true || v === 0;
            volumeSlider.value = v;
            updateVolumeIconFrom(v, muted);
            _syncingVolume = false;
        } else {
            volReadProc.running = true;
        }
    }

    Process {
        id: volReadProc
        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const r = parseWpctlVolume(text);
                if (r.vol !== null) {
                    root._syncingVolume = true;
                    volumeSlider.value = r.vol;
                    updateVolumeIconFrom(r.vol, r.muted);
                    root._syncingVolume = false;
                }
            }
        }
    }

    Timer {
        id: volPoll
        interval: 1500
        running: true
        repeat: true
        onTriggered: volReadProc.running = true
    }
    Timer {
        id: volDebounceRead
        interval: 300
        repeat: false
        onTriggered: volReadProc.running = true
    }

    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { syncVolumeFromSystem(); }
        function onMuteChanged()   { syncVolumeFromSystem(); }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { syncVolumeFromSystem(); }
    }

    // ====== LUMINOSITÀ ======
    Process {
        id: brightnessReadProc
        command: ["bash", "-lc", "c=$(brightnessctl g 2>/dev/null); m=$(brightnessctl m 2>/dev/null); if [ -n \"$c\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then printf '%d\\n' $(( 100 * c / m )); else echo -1; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim();
                const p = parseInt(t, 10);
                root._brightnessInited = true;
                brightnessSlider.value = (!isNaN(p) && p >= 0) ? p : 50;
                updateBrightnessIcon();
            }
        }
    }

    function updateBrightnessIcon() {
        var v = brightnessSlider.value;
        if (v < 30) {
            brightnessIcon.text = "\uf186";
        } else if (v < 80) {
            brightnessIcon.text = "\uf185";
        } else {
            brightnessIcon.text = "\uf0eb";
        }
    }

    // ====== UPTIME ======
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

    // ====== RETE: Process e Timer ======
    // Rileva interfaccia attiva + tipo + nome
    Process {
        id: netInfoProc
        running: false
        command: ["bash", "-lc",
            "set -e\n" +
            "if command -v nmcli >/dev/null 2>&1; then\n" +
            "  LINES=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null | awk -F: '$3==\"connected\"{print $1\"|\"$2\"|\"$4}')\n" +
            "  if [ -n \"$LINES\" ]; then\n" +
            "    E=$(printf \"%s\\n\" \"$LINES\" | awk -F'|' '$2==\"ethernet\"{print; exit}')\n" +
            "    if [ -n \"$E\" ]; then echo \"$E\"; else printf \"%s\\n\" \"$LINES\" | head -n1; fi\n" +
            "    exit 0\n" +
            "  fi\n" +
            "fi\n" +
            "IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/ dev /{for(i=1;i<=NF;i++) if ($i==\"dev\"){print $(i+1); exit}}')\n" +
            "if [ -n \"$IFACE\" ]; then\n" +
            "  if [ -d \"/sys/class/net/$IFACE/wireless\" ]; then TYPE=wifi; NAME=$(iw dev \"$IFACE\" link 2>/dev/null | awk -F': ' '/SSID:/{print $2}');\n" +
            "  else TYPE=ethernet; NAME=\"$IFACE\"; fi\n" +
            "  echo \"$IFACE|$TYPE|${NAME:-$IFACE}\"; exit 0; fi\n" +
            "echo \"\"\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = (text || "").trim();
                if (!out.length) {
                    netType = "down";
                    netIface = "";
                    netName = "";
                    netIp4 = "";
                    rxBps = 0; txBps = 0;
                    return;
                }
                const parts = out.split("|");
                netIface = parts[0] || "";
                netType  = parts[1] || "unknown";
                netName  = parts[2] || "";
                ipProc.running = true;
                // reset contatori per calcolo velocità
                root._lastRxBytes = 0;
                root._lastTxBytes = 0;
                root._lastNetTms  = 0;
                // Avvia polling rx/tx
                rxTxTimer.running = !!netIface;
            }
        }
    }

    // IP v4 dell'interfaccia
    Process {
        id: ipProc
        running: false
        command: ["bash", "-lc", "IF=\"" + netIface + "\"; [ -n \"$IF\" ] && ip -4 addr show dev \"$IF\" | awk '/inet /{print $2}' | sed 's#/.*##' | head -n1 || true" ]
        stdout: StdioCollector {
            onStreamFinished: {
                netIp4 = (text || "").trim();
            }
        }
    }

    // Poll periodico per aggiornare info rete (cambio interfaccia, ecc.)
    Timer {
        id: netInfoTimer
        interval: 4000
        running: true
        repeat: true
        onTriggered: netInfoProc.running = true
    }

    // Calcolo velocità ↓/↑ da sysfs
    Timer {
        id: rxTxTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (!netIface) return;
            rxTxProc.running = true;
        }
    }

    Process {
        id: rxTxProc
        running: false
        command: ["bash", "-lc", "IF=\"" + netIface + "\"; [ -n \"$IF\" ] && { cat /sys/class/net/$IF/statistics/rx_bytes; cat /sys/class/net/$IF/statistics/tx_bytes; } 2>/dev/null || echo -e '0\n0' "]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text || "").trim().split(/\s+/);
                if (lines.length >= 2) {
                    const now = Date.now();
                    const rx = parseFloat(lines[0]) || 0;
                    const tx = parseFloat(lines[1]) || 0;
                    if (root._lastNetTms > 0) {
                        const dt = Math.max(0.001, (now - root._lastNetTms) / 1000.0);
                        const drx = Math.max(0, rx - root._lastRxBytes);
                        const dtx = Math.max(0, tx - root._lastTxBytes);
                        rxBps = drx * 8 / dt;
                        txBps = dtx * 8 / dt;
                    }
                    root._lastRxBytes = rx;
                    root._lastTxBytes = tx;
                    root._lastNetTms  = now;
                }
            }
        }
    }
}
