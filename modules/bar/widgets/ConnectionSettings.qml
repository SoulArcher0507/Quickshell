import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "../../theme" as ThemePkg

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent

    // === Theme mapping ===
    readonly property color panelBg:       ThemePkg.Theme.surface(0.10)
    readonly property color panelBorder:   ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color primary:       ThemePkg.Theme.accent
    readonly property color textSecondary: ThemePkg.Theme.foreground

    // il contenitore esterno (connectionPanel) gestisce sfondo/bordo
    color: "transparent"
    radius: 0
    border.color: panelBorder
    border.width: 0

    implicitHeight: content.implicitHeight + margin * 2

    // Guard per sync interni
    property bool _syncingVolume: false
    property bool _brightnessInited: false

    // ---- Volume: consenti >100% (PipeWire supporta overdrive) ----
    property int volumeMaxPercent: 150

    // ---- Luminosità: consenti >100% (fino a 150%) + hook opzionale per boost software ----
    property int  brightnessMaxPercent: 150
    property string extraBrightnessCommandTemplate: ""
    property int _brightnessTarget: -1

    // ====== RETE: stato e misure ======
    property string netType: "unknown"
    property string netIface: ""
    property string netName: ""
    property string netIp4: ""
    property real   _lastRxBytes: 0
    property real   _lastTxBytes: 0
    property real   _lastNetTms:  0
    property real   rxBps: 0
    property real   txBps: 0

    // --- helper per rigenerare il comando IP quando cambia interfaccia ---
    function _refreshIpCommand() {
        ipProc.command = [
            "bash", "-lc",
            "IF=\"" + netIface + "\"; " +
            "[ -n \"$IF\" ] && ip -4 addr show dev \"$IF\" | awk '/inet /{print $2}' | sed 's#/.*##' | head -n1 || true"
        ];
    }

    onNetIfaceChanged: {
        if (netIface && netIface.length) {
            _refreshIpCommand();
            ipProc.running = false;
            ipProc.running = true;

            _lastRxBytes = 0;
            _lastTxBytes = 0;
            _lastNetTms  = 0;
        } else {
            netIp4 = "";
        }
    }

    function _humanBitsPerSec(bps) {
        var u = ["b/s","Kb/s","Mb/s","Gb/s","Tb/s"];
        var val = bps;
        var i = 0;
        while (val >= 1000 && i < u.length - 1) { val /= 1000; i++; }
        return (val >= 100 ? Math.round(val) : Math.round(val*10)/10) + " " + u[i];
    }

    function _updateTooltipText() {
        if (netType === "down") return "No Connections";
        var t = (netType === "ethernet") ? "Ethernet" : (netType === "wifi" ? "Wi-Fi" : "Rete");
        var name = (netName && netName.length) ? netName : "(sconosciuta)";
        var ip = (netIp4 && netIp4.length) ? netIp4 : "—";
        var down = _humanBitsPerSec(rxBps);
        var up   = _humanBitsPerSec(txBps);
        return t + ": " + name +
               "\nInterface: " + netIface +
               "\nIP: " + ip +
               "\n↓ " + down + "   ↑ " + up;
    }

    function _pickIconForNet() {
        if (netType === "ethernet") return "";
        if (netType === "wifi")     return "";
        return "";
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
        volPoll.running = (Pipewire.defaultAudioSink === null || Pipewire.defaultAudioSink === undefined);

        // luminosità: prima lettura
        brightnessReadProc.running = true;

        // rete init
        netInfoProc.running = true;
    }

    // quando la finestra diventa visibile: sync immediato
    onVisibleChanged: {
        if (visible) {
            syncVolumeFromSystem();
            brightnessReadProc.running = true;
        }
    }

    focus: true
    Keys.onReleased: function(event) {
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
        onClicked: function(mouse) {
            const local = mapToItem(content, mouse.x, mouse.y);
            if (local.x < 0 || local.y < 0 || local.x > content.width || local.y > content.height) {
                const w = QsWindow.window;
                if (w) w.visible = false; else root.visible = false;
            }
        }
    }

    // --- helper: imposta valore slider da una x locale (click/drag su barra) ---
    function _setSliderFromX(slider, x) {
        const rel = Math.max(0, Math.min(1,
                     (x - slider.leftPadding) / Math.max(1, slider.availableWidth)));
        slider.value = slider.from + rel * (slider.to - slider.from);
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
                color: primary
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
                color: (netType === "down" || netType === "unknown")
                         ? ThemePkg.Theme.surface(0.06)
                         : primary

                Text {
                    id: netIcon
                    anchors.centerIn: parent
                    text: _pickIconForNet()
                    color: ThemePkg.Theme.c15
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
                color: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                         ? primary
                         : ThemePkg.Theme.surface(0.06)

                Text {
                    anchors.centerIn: parent
                    text: "\uf293"
                    color: ThemePkg.Theme.c15
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
                        if (!Bluetooth.defaultAdapter) return "Bluetooth not Available";
                        let names = [];
                        try {
                            const n = Bluetooth.devices ? Bluetooth.devices.count : 0;
                            for (let i = 0; i < n; ++i) {
                                const d = Bluetooth.devices.get(i);
                                if (d && d.connected) names.push(d.name || d.deviceName || d.address);
                            }
                        } catch(e) {}
                        return names.length ? names.join(", ") : "No Device Connected";
                    }
                }
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Profili energia
            Rectangle {
                id: powerProfilesGroup
                Layout.preferredHeight: 24
                Layout.preferredWidth: segmentCount * segmentWidth + segmentSpacing * (segmentCount - 1)
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                color: "transparent"
                border.width: 0
                antialiasing: true

                property color baseFill:   ThemePkg.Theme.surface(0.06)
                property color iconColor:  ThemePkg.Theme.c15
                property color accent:     primary
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

                function profileName(k) {
                    if (k === PowerProfile.PowerSaver)  return "Power Saver";
                    if (k === PowerProfile.Balanced)    return "Balanced";
                    if (k === PowerProfile.Performance) return "Performance";
                    return "";
                }

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
                                id: segArea
                                anchors.fill: parent
                                enabled: !seg.disabledBtn
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function() { powerProfilesGroup.pp.profile = modelData.key; }
                            }

                            ToolTip {
                                visible: segArea.containsMouse
                                delay: 200
                                text: {
                                    var name = powerProfilesGroup.profileName(modelData.key);
                                    var extra = "";
                                    if (seg.disabledBtn) extra = " (non disponibile)";
                                    else if (powerProfilesGroup.pp.profile === modelData.key) extra = " (active)";
                                    return name + extra;
                                }
                            }
                        }
                    }
                }
            }
        }

        // SLIDER 1 — VOLUME (live, mouse/rotella, >100%)
        RowLayout {
            id: volumeRow
            width: parent.width
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: panelBg
                Text {
                    id: volumeIcon
                    text: "\uf027"
                    color: primary
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
                to: root.volumeMaxPercent
                value: 50
                live: true

                // click su qualsiasi punto della barra
                TapHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                    onTapped: {
                        const local = volumeSlider.mapFromScene(eventPoint.scenePosition);
                        _setSliderFromX(volumeSlider, local.x);
                        applyVolume(Math.round(volumeSlider.value));
                    }
                }
                // drag su tutta la barra
                DragHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                    onCentroidChanged: {
                        if (active) {
                            const local = volumeSlider.mapFromScene(centroid.scenePosition);
                            _setSliderFromX(volumeSlider, local.x);
                            applyVolume(Math.round(volumeSlider.value));
                        }
                    }
                    onActiveChanged: {
                        if (!active) volDebounceRead.restart();
                    }
                }

                // continua a funzionare anche il drag nativo dell'handle
                onMoved: applyVolume(Math.round(value))

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 8
                    radius: 4
                    color: ThemePkg.Theme.surface(0.06)
                    border.color: panelBorder
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: ThemePkg.Theme.c15
                    border.color: panelBorder
                }

                WheelHandler {
                    onWheel: function(e) {
                        const step = 5;
                        volumeSlider.value = Math.min(
                            volumeSlider.to,
                            Math.max(volumeSlider.from,
                                     volumeSlider.value + step * e.angleDelta.y / 120)
                        );
                        applyVolume(Math.round(volumeSlider.value));
                    }
                }
            }
        }

        // SLIDER 2 — LUMINOSITÀ (live, mouse/rotella, >100% con hook opzionale)
        RowLayout {
            id: brightnessRow
            width: parent.width
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: panelBg
                Text {
                    id: brightnessIcon
                    text: "\uf185"
                    color: primary
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
                to: root.brightnessMaxPercent
                value: 0
                live: true

                // click ovunque sulla barra
                TapHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                    onTapped: {
                        const local = brightnessSlider.mapFromScene(eventPoint.scenePosition);
                        _setSliderFromX(brightnessSlider, local.x);
                        applyBrightness(Math.round(brightnessSlider.value));
                    }
                }
                // drag su tutta la barra
                DragHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                    onCentroidChanged: {
                        if (active) {
                            const local = brightnessSlider.mapFromScene(centroid.scenePosition);
                            _setSliderFromX(brightnessSlider, local.x);
                            applyBrightness(Math.round(brightnessSlider.value));
                        }
                    }
                    onActiveChanged: {
                        if (!active) brightDebounceRead.restart();
                    }
                }

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth
                    height: 8
                    radius: 4
                    color: ThemePkg.Theme.surface(0.06)
                    border.color: panelBorder
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: ThemePkg.Theme.c15
                    border.color: panelBorder
                }

                WheelHandler {
                    onWheel: function(e) {
                        const step = 5;
                        brightnessSlider.value = Math.min(
                            brightnessSlider.to,
                            Math.max(brightnessSlider.from,
                                     brightnessSlider.value + step * e.angleDelta.y / 120)
                        );
                        applyBrightness(Math.round(brightnessSlider.value));
                    }
                }
            }
        }
    }

    // ====== VOLUME: helper ======
    function updateVolumeIconFrom(v, muted) {
        if (muted || v === 0) {
            volumeIcon.text = "\uf026";
        } else if (v < 50) {
            volumeIcon.text = "\uf027";
        } else {
            volumeIcon.text = "\uf028";
        }
    }

    function applyVolume(vPercent) {
        const vmax = Math.max(100, root.volumeMaxPercent);
        const v = Math.max(0, Math.min(vmax, vPercent));
        const ratio = (v / 100.0);

        if (Pipewire.defaultAudioSink && !isNaN(Pipewire.defaultAudioSink.volume) && v <= 100) {
            Pipewire.defaultAudioSink.volume = ratio;
            Pipewire.defaultAudioSink.mute   = (v === 0);
        } else {
            Hyprland.dispatch("exec wpctl set-volume @DEFAULT_AUDIO_SINK@ " + ratio.toFixed(2));
            Hyprland.dispatch("exec wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (v === 0 ? "1" : "0"));
        }

        updateVolumeIconFrom(v, v === 0);
        volDebounceRead.restart();
    }

    function parseWpctlVolume(out) {
        const s = (out || "").trim();
        let pct = null;
        const mPct = s.match(/\[([0-9]{1,3})%\]/);
        if (mPct) pct = parseInt(mPct[1], 10);
        const m = s.match(/([0-9]+(?:\.[0-9]+)?)/);
        const vol = (pct !== null) ? pct : (m ? Math.round(parseFloat(m[1]) * 100) : null);
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
                    if (r.vol > root.volumeMaxPercent) {
                        root.volumeMaxPercent = Math.min(200, Math.max(root.volumeMaxPercent, r.vol));
                    }
                    root._syncingVolume = true;
                    volumeSlider.value = r.vol;
                    updateVolumeIconFrom(r.vol, r.muted);
                    root._syncingVolume = false;
                }
            }
        }
    }

    // Poll di fallback (quando NON c'è sink PipeWire)
    Timer {
        id: volPoll
        interval: 1500
        running: Pipewire.defaultAudioSink === null || Pipewire.defaultAudioSink === undefined
        repeat: true
        onTriggered: volReadProc.running = true
    }

    // Poll visibile per volume (leggero)
    Timer {
        id: visibleVolTick
        interval: 400
        running: root.visible
        repeat: true
        onTriggered: {
            if (!volumeSlider.pressed) volReadProc.running = true;
        }
    }

    // Debounce volume
    Timer {
        id: volDebounceRead
        interval: 220
        repeat: false
        onTriggered: { if (!volumeSlider.pressed) volReadProc.running = true; }
    }

    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { if (!volumeSlider.pressed) syncVolumeFromSystem(); }
        function onMuteChanged()   { if (!volumeSlider.pressed) syncVolumeFromSystem(); }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            volPoll.running = (Pipewire.defaultAudioSink === null || Pipewire.defaultAudioSink === undefined);
            syncVolumeFromSystem();
        }
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

                const hw = (!isNaN(p) && p >= 0) ? p : 50;
                const target = (root._brightnessTarget >= 0) ? root._brightnessTarget : hw;
                const show = Math.max(hw, target);

                if (!brightnessSlider.pressed) brightnessSlider.value = show;
                updateBrightnessIcon();
            }
        }
    }

    function applyBrightness(vPercent) {
        const bmax = Math.max(100, root.brightnessMaxPercent);
        const v = Math.max(0, Math.min(bmax, vPercent));
        root._brightnessTarget = v;

        const hw = Math.min(100, v);
        Hyprland.dispatch("exec brightnessctl set " + Math.round(hw) + "%");

        if (v > 100 && root.extraBrightnessCommandTemplate.length > 0) {
            const factor = (v / 100.0);
            const cmd = root.extraBrightnessCommandTemplate.replace("${factor}", factor.toFixed(2));
            Hyprland.dispatch("exec bash -lc " + JSON.stringify(cmd));
        }
        updateBrightnessIcon();
        brightDebounceRead.restart();
    }

    Timer {
        id: visibleBrightTick
        interval: 500
        running: root.visible
        repeat: true
        onTriggered: {
            if (!brightnessSlider.pressed) brightnessReadProc.running = true;
        }
    }

    Timer {
        id: brightDebounceRead
        interval: 220
        repeat: false
        onTriggered: {
            if (!brightnessSlider.pressed) brightnessReadProc.running = true;
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
                // ipProc viene avviato da onNetIfaceChanged
            }
        }
    }

    Process {
        id: ipProc
        running: false
        command: ["bash", "-lc", "true"]
        stdout: StdioCollector {
            onStreamFinished: { netIp4 = (text || "").trim(); }
        }
    }

    Timer {
        id: netInfoTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netInfoProc.running = true
    }

    Timer {
        id: rxTxTimer
        interval: 1000
        running: netIface && netIface.length > 0
        repeat: true
        onTriggered: { rxTxProc.running = true; }
    }

    Process {
        id: rxTxProc
        running: false
        command: ["bash", "-lc", "IF=\"" + netIface + "\"; [ -n \"$IF\" ] && { cat /sys/class/net/$IF/statistics/rx_bytes; cat /sys/class/net/$IF/statistics/tx_bytes; } 2>/dev/null || echo -e '0\\n0' "]
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
