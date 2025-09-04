import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import "widgets/"
import org.kde.layershell 1.0
import Quickshell.Io
import "../theme" as ThemePkg
import Quickshell.Services.UPower   
import QtQuick.Layouts 1.15
import Quickshell.Io as Io
import QtQuick.Controls as QQC2


// Create a proper panel window
Variants {
    id: bar
    model: Quickshell.screens;
    
    readonly property color moduleColor:       ThemePkg.Theme.surface(0.10)
    readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color moduleFontColor:   ThemePkg.Theme.accent

    readonly property color workspaceActiveColor:        ThemePkg.Theme.c7
    readonly property color workspaceInactiveColor: moduleColor
    readonly property color workspaceActiveFontColor:    ThemePkg.Theme.accent
    readonly property color workspaceInactiveFontColor:  moduleFontColor

    delegate: Component {
        Item {
            id: delegateRoot
            required property var modelData

            // ---------------------------
            // Overlay manager con animazioni (senza scrim)
            // ---------------------------
            PanelWindow {
                id: overlayWindow
                focusable: true
                screen: delegateRoot.modelData
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                visible: (switcher.shownOverlay !== "") || (switcher.pendingIndex !== -1)
                onVisibleChanged: if (visible) switcher.forceActiveFocus()

                // Click-outside per chiudere
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: switcher.close()
                }

                // Switcher con doppio Loader per cross-fade/scale
                Item {
                    id: switcher
                    anchors.fill: parent
                    z: 1
                    focus: overlayWindow.visible

                    // ===== Cache aggiornamenti (persistente finché Quickshell è aperto) =====
                    property int    updPacman: panel.updPacman
                    property int    updAur: panel.updAur
                    property int    updFlatpak: panel.updFlatpak
                    property int    updTotal: panel.updTotal
                    property string updLastTs: panel.updLastTs
                    property var    _updLastMs: panel._updLastMs              // ms epoch dell’ultimo check
                    property int    updatesMinIntervalMs: panel.updatesMinIntervalMs



                    // "", "connection", "notifications", "power", "arch"
                    property string shownOverlay: ""
                    property int    dur: 140
                    property real   scaleIn: 0.98
                    property real   scaleOut: 1.02

                    property int    pendingIndex: -1
                    property string pendingShownOverlay: ""

                    // ===== Autolock/Hypridle state (persistente) =====
                    property bool autolockDisabled: false
                    property string autolockStatusCmd: "pgrep -x hypridle" // 0=running(ON)  !=0=OFF
                    property int autolockStatusPollMs: 3000

                    Process {
                        id: autolockStatusProc
                        command: ["bash", "-lc", switcher.autolockStatusCmd]
                        onExited: function(exitCode, exitStatus) {
                            switcher.autolockDisabled = (exitCode !== 0);
                        }
                    }
                    Timer {
                        id: autolockPoll
                        interval: switcher.autolockStatusPollMs
                        running: true
                        repeat: true
                        onTriggered: autolockStatusProc.exec(["bash","-lc", switcher.autolockStatusCmd])
                    }
                    Timer {
                        id: autolockRecheck
                        interval: 350
                        repeat: false
                        onTriggered: autolockStatusProc.exec(["bash","-lc", switcher.autolockStatusCmd])
                    }
                    

                    Timer {
                        id: finalizeClose
                        interval: switcher.dur
                        repeat: false
                        onTriggered: {
                            var L = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            L.sourceComponent = null;
                            switcher.shownOverlay = "";
                            switcher.pendingIndex = -1;
                        }
                    }
                    Timer {
                        id: finalizeSwap
                        interval: switcher.dur
                        repeat: false
                        onTriggered: {
                            var outL = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            outL.sourceComponent = null;
                            switcher.activeIndex = (switcher.pendingIndex === 0 ? 1 : 0);
                            switcher.shownOverlay = switcher.pendingShownOverlay;
                            switcher.pendingIndex = -1;
                        }
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape) {
                            switcher.close();
                            event.accepted = true;
                        }
                    }

                    function compFor(which) {
                        return which === "connection"     ? connectionComp
                             : which === "notifications"  ? notificationsComp
                             : which === "power"          ? powerComp
                             : which === "arch"           ? archComp
                             : which === "wallpaper"      ? wallpaperComp
                             : null;
                    }

                    Loader {
                        id: loaderA
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 1.0
                        scale: 1.0
                        z: 1
                        Behavior on opacity { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                    }
                    Loader {
                        id: loaderB
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 0.0
                        scale: 1.0
                        z: 2
                        Behavior on opacity { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: switcher.dur; easing.type: Easing.OutCubic } }
                    }

                    property int activeIndex: 0
                    function currentLoader() { return activeIndex === 0 ? loaderA : loaderB }
                    function otherLoader()   { return activeIndex === 0 ? loaderB : loaderA }

                    function open(which) {
                        if (!which) return;
                        var L = currentLoader();
                        L.sourceComponent = compFor(which);
                        L.opacity = 0.0;
                        L.scale = scaleIn;
                        L.opacity = 1.0;
                        L.scale = 1.0;
                        shownOverlay = which;
                    }

                    function close() {
                        if (shownOverlay === "" && pendingIndex === -1) return;
                        var L = currentLoader();
                        L.opacity = 0.0;
                        L.scale = scaleOut;
                        pendingIndex = activeIndex;
                        finalizeClose.start();
                    }

                    function swap(which) {
                        if (!which || which === shownOverlay) return;
                        var outL = currentLoader();
                        var inL  = otherLoader();

                        inL.sourceComponent = compFor(which);
                        inL.opacity = 0.0;
                        inL.scale   = scaleIn;

                        outL.opacity = 0.0;
                        outL.scale   = scaleOut;
                        inL.opacity  = 1.0;
                        inL.scale    = 1.0;

                        pendingIndex = activeIndex;
                        pendingShownOverlay = which;
                        finalizeSwap.start();
                    }

                    function toggle(which) {
                        if (!which) return;
                        if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                            switcher.open(which);
                        } else if (switcher.shownOverlay === which) {
                            switcher.close();
                        } else {
                            switcher.swap(which);
                        }
                    }

                    GlobalShortcut {
                        appid: "quickshell"         // scegli un appid e non cambiarlo più
                        name: "power-toggle"        // deve essere univoco per appid
                        description: "Toggle power menu"
                        onPressed: switcher.toggle("power")
                    }

                    IpcHandler {
                        target: "power"
                        // NB: per l'IPC le firme vanno tipizzate
                        function toggle(): void { switcher.toggle("power") }
                    }
                }
            }

            // --------
            // Component caricati on-demand
            // --------
            Component {
                id: connectionComp
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: connectionPanel
                        width: 300
                        height: connectionContent.implicitHeight
                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }
                        ConnectionSettings { id: connectionContent; anchors.fill: parent }
                    }
                }
            }

            Component {
                id: notificationsComp
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: notificationPanel
                        property int sideMargin: 16
                        width:  Math.min(notificationContent.implicitWidth,  overlayWindow.width  - sideMargin*2)
                        height: Math.min(notificationContent.implicitHeight, overlayWindow.height - sideMargin*2)

                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }
                        Notifications { id: notificationContent; anchors.fill: parent }
                    }
                }
            }

            Component {
                id: powerComp
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: powerDialog
                        width: 480
                        height: 320
                        radius: 12
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors.centerIn: parent
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Power"
                                color: moduleFontColor
                                font.pixelSize: 16
                                font.family: "Fira Sans Semibold"
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Grid {
                                anchors.horizontalCenter: parent.horizontalCenter
                                rows: 2; columns: 3
                                rowSpacing: 12; columnSpacing: 12

                                // Lock
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Lock"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec hyprlock"); } }
                                }
                                // Logout
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Logout"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exit"); } }
                                }
                                // Suspend
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Suspend"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl suspend"); } }
                                }
                                // Hibernate
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Hibernate"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl hibernate"); } }
                                }
                                // Reboot
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Reboot"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl reboot"); } }
                                }
                                // Shutdown
                                Rectangle {
                                    width: 140; height: 120; radius: 10
                                    color: moduleColor
                                    border.color: moduleBorderColor; border.width: 1
                                    Column {
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: ""; font.pixelSize: 34; font.family: "CaskaydiaMono Nerd Font"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Shutdown"; font.pixelSize: 13; font.family: "Fira Sans Semibold"; color: moduleFontColor; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hyprland.dispatch("exec systemctl poweroff"); } }
                                }
                            }
                        }
                    }
                }
            }

            // =======================
            // OVERLAY: ARCH (EN tooltips + autolock state via Quickshell.Io.Process)
            // =======================
            Component {
                id: archComp
                Item {
                    anchors.fill: parent

                    // === Your scripts here ===
                    property string changeWallpaperScript: "$HOME/.config/swaybg/wallpaper.sh"
                    property string toggleAutolockScript: "$HOME/.config/waybar/scripts/hypridle.sh"
                    // property string openClipboardScript:  "$HOME/.config/waybar/scripts/cliphist.sh"

                    // === Nuovi script aggiornamenti (li fornisco nel prossimo messaggio) ===
                    property string updatesCheckScript:   "$HOME/.config/hypr/scripts/updates-check.sh"
                    property string updatesAllScript:     "$HOME/.config/hypr/scripts/update-all.sh"
                    property string updatePacmanScript:   "$HOME/.config/hypr/scripts/update-pacman.sh"
                    property string updateAurScript:      "$HOME/.config/hypr/scripts/update-aur.sh"       // yay/AUR
                    property string updateFlatpakScript:  "$HOME/.config/hypr/scripts/update-flatpak.sh"
                    // Listing scripts (for right-click popup)
                    property string updatesListAllScript:     "$HOME/.config/hypr/scripts/updates-list-all.sh"
                    property string updatesListPacmanScript:  "$HOME/.config/hypr/scripts/updates-list-pacman.sh"
                    property string updatesListAurScript:     "$HOME/.config/hypr/scripts/updates-list-aur.sh"
                    property string updatesListFlatpakScript: "$HOME/.config/hypr/scripts/updates-list-flatpak.sh"



                    // Check real Hypridle status: exit 0 => running (autolock ON), non-zero => not running (autolock OFF)
                    property string autolockStatusCmd: "pgrep -x hypridle"
                    property int    autolockStatusPollMs: 3000

                    // true => autolock disabled (Hypridle OFF)
                    property bool autolockDisabled: false

                    // === Stato aggiornamenti ===
                    property int    updPacman:  switcher.updPacman
                    property int    updAur:     switcher.updAur
                    property int    updFlatpak: switcher.updFlatpak
                    property int    updTotal:   switcher.updTotal
                    property string updLastTs:  switcher.updLastTs

                    function runScript(path, holdOpen) {
                        if (!path || path.trim() === "") return;

                        // Se holdOpen = true, resta aperto a fine comando
                        var hold = holdOpen ? "; echo; read -p 'Premi INVIO per chiudere...' _" : "";

                        // Prova vari terminali; esegue: <terminal> -e bash -lc "<comando>"
                        var cmd =
                            "(command -v foot >/dev/null && foot -e bash -lc \\\"" + path + hold + "\\\")" +
                            " || (command -v kitty >/dev/null && kitty -e bash -lc \\\"" + path + hold + "\\\")" +
                            " || (command -v alacritty >/dev/null && alacritty -e bash -lc \\\"" + path + hold + "\\\")" +
                            " || (command -v wezterm >/dev/null && wezterm -e bash -lc \\\"" + path + hold + "\\\")" +
                            " || (command -v gnome-terminal >/dev/null && gnome-terminal -- bash -lc \\\"" + path + hold + "\\\")" +
                            " || (command -v xterm >/dev/null && xterm -e bash -lc \\\"" + path + hold + "\\\")";

                        Hyprland.dispatch('exec [float;center;size 60% 70%] ' + cmd);
                    }


                    function _listScript(kind) {
                        if (kind === "all")     return updatesListAllScript;
                        if (kind === "pacman")  return updatesListPacmanScript;
                        if (kind === "aur")     return updatesListAurScript;
                        if (kind === "flatpak") return updatesListFlatpakScript;
                        return "";
                    }

                    property bool   listVisible: false
                    property bool   listLoading: false
                    property string listTitle:   ""
                    property string listText:    ""
                    property string listKind:    ""

                    // ===== Overlay terminale interattivo (click sinistro) =====
                    property bool   termVisible: false
                    property string termTitle:   ""
                    property string termKind:    ""
                    property string termScript:  ""
                    property bool   termPasswordMode: false

                    function _updateScript(kind) {
                        if (kind === "all")     return updatesAllScript
                        if (kind === "pacman")  return updatePacmanScript
                        if (kind === "aur")     return updateAurScript
                        if (kind === "flatpak") return updateFlatpakScript
                        return ""
                    }
                    function showTerm(kind) {
                        var s = _updateScript(kind)
                        if (!s) return
                        termKind   = kind
                        termTitle  = (kind === "all")     ? "Tutti gli aggiornamenti"
                                : (kind === "pacman")  ? "Aggiorna pacman"
                                : (kind === "aur")     ? "Aggiorna AUR"
                                :                        "Aggiorna Flatpak"
                        termScript = s
                        termVisible = true
                        termStartTimer.restart()
                    }

                    // eseguo poco dopo l’apertura per dare focus all’input
                    Timer {
                        id: termStartTimer
                        interval: 10
                        repeat: false
                        onTriggered: {
                            // PTY con `script` se presente; fallback a bash “normale”
                            const cmd = 'if command -v script >/dev/null; then ' +
                                        'script -qefc "bash -lc \\"' + termScript.replace(/"/g, '\\"') + '\\"" /dev/null; ' +
                                        'else bash -lc "' + termScript.replace(/"/g, '\\"') + '"; fi'
                            termProc.exec(["bash","-lc", cmd])
                        }
                    }

                    Process {
                        id: termProc
                        stdinEnabled: true

                        stdout: SplitParser {
                            splitMarker: "\n"
                            onRead: (line) => handleTermLine(line)
                        }
                        stderr: SplitParser {
                            splitMarker: "\n"
                            onRead: (line) => handleTermLine(line)
                        }

                        onStarted: {
                            termOutput.text = `$ ${termScript}\n`
                            termInput.forceActiveFocus()
                        }
                        onExited: (code, status) => {
                            termOutput.append(`\n[Processo terminato] exit=${code}\n`)
                            termPasswordMode = false
                            // Ricontrolla i numeri a fine update
                            updatesRecheckSoon.start()
                        }
                    }

                    function handleTermLine(line) {
                        termOutput.append(line + "\n")
                        if (/assword.*: *$/i.test(line) || /\[sudo\] password/i.test(line))
                            termPasswordMode = true
                        termOutput.cursorPosition = termOutput.length
                    }


                    // apri e carica
                    function showPkgList(kind) {
                        var s = _listScript(kind);
                        if (!s) return;

                        listKind   = kind;
                        listTitle  = (kind === "all") ? "All Updates"
                                : (kind === "pacman") ? "Pacman"
                                : (kind === "aur") ? "AUR"
                                : "Flatpak";
                        listText    = "Caricamento…";
                        listVisible = true;
                        listLoading = true;

                        // esegue lo script e mostra l'output
                        updatesListProc.exec(["bash","-lc", s]);
                    }




                    // --- Hypridle status ---
                    Process {
                        id: autolockStatusProc
                        command: ["bash", "-lc", autolockStatusCmd]
                        onExited: function (exitCode, exitStatus) {
                            autolockDisabled = (exitCode !== 0);
                        }
                    }
                    Timer {
                        id: autolockPoll
                        interval: autolockStatusPollMs
                        running: true
                        repeat: true
                        onTriggered: autolockStatusProc.exec(["bash","-lc", autolockStatusCmd])
                    }
                    Timer {
                        id: autolockRecheck
                        interval: 350
                        repeat: false
                        onTriggered: autolockStatusProc.exec(["bash","-lc", autolockStatusCmd])
                    }

                    // --- Update counts (robusto anche se lo script ancora non c'è) ---
                    // Conta aggiornamenti con fallback alle liste, robusto contro sudo/tilde
                    property string _updatesCheckCmd: "$HOME/.config/hypr/scripts/updates-check.sh"

                    Process {
                        id: updatesCheckProc
                        command: ["bash", "-lc", _updatesCheckCmd]
                        stdout: StdioCollector { id: updatesCheckOut; waitForEnd: true }

                        onExited: function(exitCode, exitStatus) {
                            var raw = (updatesCheckOut.text || "").trim();
                            var start = raw.lastIndexOf("{");
                            var end   = raw.lastIndexOf("}");
                            var json  = (start !== -1 && end !== -1 && end > start) ? raw.slice(start, end + 1) : raw;

                            var pc = 0, aur = 0, fl = 0, tot = 0;
                            try {
                                var obj = JSON.parse(json);
                                pc  = Number(obj.pacman  || 0);
                                aur = Number(obj.aur     || 0);
                                fl  = Number(obj.flatpak || 0);
                                tot = Number(obj.total   || (pc + aur + fl));
                            } catch(e) {
                                pc = aur = fl = tot = 0;
                            }

                            // aggiorna SOLO la cache persistente
                            switcher.updPacman  = pc;
                            switcher.updAur     = aur;
                            switcher.updFlatpak = fl;
                            switcher.updTotal   = tot;
                            switcher.updLastTs  = Qt.formatDateTime(new Date(), "HH:mm");
                            switcher._updLastMs = Date.now();
                        }

                    }

                    Process {
                        id: updatesListProc
                        // comando passato runtime via .exec(["bash","-lc", <script>])
                        stdout: StdioCollector { id: updatesListOut; waitForEnd: true }
                        onExited: function(exitCode, exitStatus) {
                            listLoading = false;
                            var raw = (updatesListOut.text || "").trim();
                            // Mostra l'output esatto dei tuoi script (con versioni, ecc.)
                            listText = raw.length ? raw : "(no packages)";
                        }
                    }



                    // Overlay per la lista pacchetti
                    Rectangle {
                        id: listOverlay
                        anchors.fill: parent
                        visible: listVisible
                        z: 9999
                        color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.background, 0.45)

                        // click fuori per chiudere
                        MouseArea { anchors.fill: parent; onClicked: listVisible = false }

                        // card centrale (autosize con limiti)
                        Rectangle {
                            id: listCard
                            anchors.centerIn: parent
                            radius: 14
                            color: ThemePkg.Theme.surface(0.08)
                            border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.14)
                            border.width: 1

                            // ==== LIMITE MASSIMO (come prima) ====
                            readonly property int maxCardW: Math.min(parent.width * 0.55, 760)
                            readonly property int maxCardH: Math.min(parent.height * 0.65, 560)

                            // ==== MINIMI per non farla microscopica ====
                            readonly property int minCardW: 320
                            readonly property int minBodyH: 120

                            // ==== METRICHE MONO (coerenti con TextArea) ====
                            FontMetrics {
                                id: monoFm
                                font.family: "CaskaydiaMono Nerd Font"
                                font.pixelSize: 12
                            }

                            // ==== Calcolo righe e lunghezza massima ====
                            readonly property var _linesArr: (listText && listText.length) ? listText.split("\n") : (listLoading ? ["Caricamento…"] : ["(nessun pacchetto)"])
                            readonly property int _lines: _linesArr.length
                            readonly property int _maxLen: {
                                var m = 0;
                                for (var i = 0; i < _linesArr.length; ++i) m = Math.max(m, _linesArr[i].length);
                                Math.max(m, 8) // evita larghezze ridicole
                            }

                            // ==== Spazi interni (margini + scrollbar) ====
                            readonly property int _sidePad: 40   // testo, bordi, scrollbar
                            readonly property int _topPad: 14
                            readonly property int _bottomPad: 14
                            readonly property int _betweenPad: 10  // spazio tra header e corpo

                            // ==== Header dinamico (leggiamo la sua altezza reale) ====
                            // (definito sotto come RowLayout { id: headerRow })
                            readonly property int _headerH: headerRow.implicitHeight

                            // ==== Dimensioni desiderate ====
                            readonly property real _desiredBodyW: Math.ceil(_maxLen * monoFm.averageCharacterWidth) + _sidePad
                            readonly property int  _desiredBodyH: Math.ceil(_lines * monoFm.height) + 12

                            readonly property int  _maxBodyH: Math.max(0, maxCardH - (_topPad + _headerH + _betweenPad + _bottomPad))
                            readonly property int  _bodyH: Math.min(_maxBodyH, Math.max(minBodyH, _desiredBodyH))

                            width:  Math.min(maxCardW, Math.max(minCardW, _desiredBodyW + _topPad + _bottomPad))
                            height: _topPad + _headerH + _betweenPad + _bodyH + _bottomPad

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // ====== header ======
                                RowLayout {
                                    id: headerRow
                                    spacing: 8
                                    width: parent.width

                                    Text {
                                        text: listTitle
                                        color: ThemePkg.Theme.foreground
                                        font.pixelSize: 16
                                        font.family: "Fira Sans Semibold"
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true } // spacer

                                    Rectangle {
                                        width: 28; height: 28; radius: 8
                                        color: "transparent"
                                        border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12)
                                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                                        MouseArea { anchors.fill: parent; onClicked: listVisible = false; cursorShape: Qt.PointingHandCursor }
                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: ThemePkg.Theme.foreground
                                            font.pixelSize: 14
                                            font.family: "CaskaydiaMono Nerd Font"
                                        }
                                    }
                                }

                                // ====== corpo scrollabile ======
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: ThemePkg.Theme.surface(0.04)
                                    border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.10)
                                    border.width: 1

                                    ScrollView {
                                        anchors.fill: parent
                                        clip: true
                                        TextArea {
                                            id: listArea
                                            readOnly: true
                                            wrapMode: Text.NoWrap
                                            text: listText && listText.length ? listText : (listLoading ? "Caricamento…" : "(nessun pacchetto)")
                                            font.family: "CaskaydiaMono Nerd Font"
                                            font.pixelSize: 12
                                            color: ThemePkg.Theme.foreground
                                            background: Rectangle { color: "transparent" }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    // ===== Overlay terminale (stile finestra a destra) =====
                    Rectangle {
                        id: termOverlay
                        anchors.fill: parent
                        visible: termVisible
                        z: 9999
                        color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.background, 0.45)

                        // click fuori chiude
                        MouseArea { anchors.fill: parent; onClicked: termVisible = false }

                        // card centrale
                        Rectangle {
                            id: termCard
                            anchors.centerIn: parent
                            width: Math.min(900, parent.width - 80)
                            height: Math.min(560, parent.height - 80)
                            radius: 14
                            color: ThemePkg.Theme.surface(0.08)
                            border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.14)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: termTitle
                                        color: ThemePkg.Theme.foreground
                                        font.pixelSize: 16
                                        font.family: "Fira Sans Semibold"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        text: termProc.running ? "Stop" : "Chiudi"
                                        onClicked: termProc.running ? termProc.signal(2) : (termVisible = false)
                                        background: Rectangle {
                                            radius: 8
                                            color: ThemePkg.Theme.surface(0.16)
                                            border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12)
                                            border.width: 1
                                        }
                                    }
                                }

                                // output
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 380
                                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                    TextArea {
                                        id: termOutput
                                        readOnly: true
                                        wrapMode: TextArea.NoWrap
                                        textFormat: TextEdit.PlainText
                                        selectByMouse: true
                                        persistentSelection: true
                                        font.family: "monospace"
                                        color: ThemePkg.Theme.foreground
                                        background: Rectangle { color: ThemePkg.Theme.surface(0.06); radius: 10 }
                                    }
                                }

                                // input
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    TextField {
                                        id: termInput
                                        Layout.fillWidth: true
                                        placeholderText: termPasswordMode ? "Password sudo…" : "Invia riga (Invio)"
                                        echoMode: termPasswordMode ? TextInput.Password : TextInput.Normal
                                        onAccepted: {
                                            if (!termProc.running) return
                                            termProc.write(text + "\n")
                                            text = ""
                                            if (termPasswordMode) termPasswordMode = false
                                        }
                                        background: Rectangle { color: ThemePkg.Theme.surface(0.06); radius: 10 }
                                    }
                                    Button {
                                        text: "Invia"
                                        enabled: termProc.running
                                        onClicked: termInput.accepted()
                                    }
                                }
                            }
                        }
                    }


                    Timer {
                        id: updatesPoll
                        interval: 15 * 60 * 1000   // ogni 15 minuti
                        running: true
                        repeat: true
                        onTriggered: updatesCheckProc.exec(["bash","-lc", _updatesCheckCmd])
                    }


                    // Recheck poco dopo aver lanciato un update
                    Timer {
                        id: updatesRecheckSoon
                        interval: 5000
                        repeat: false
                        onTriggered: updatesCheckProc.exec(["bash","-lc", _updatesCheckCmd])
                    }

                    Component.onCompleted: {
                        autolockStatusProc.exec(["bash","-lc", autolockStatusCmd]);

                        var now = Date.now();
                        if ((now - (switcher._updLastMs || 0)) > switcher.updatesMinIntervalMs
                            || (switcher._updLastMs === 0 && switcher.updTotal === 0)) {
                            // prima volta o cache vecchia -> aggiorna in background
                            updatesCheckProc.exec(["bash","-lc", _updatesCheckCmd]);
                        }
                    }

                    Rectangle {
                        id: archPanel
                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }

                        width: Math.max(220, contentBox.implicitWidth + 24)
                        height: contentBox.implicitHeight + 24

                        Column {
                            id: contentBox
                            anchors { top: parent.top; left: parent.left; topMargin: 12; leftMargin: 12; rightMargin: 12 }
                            spacing: 10

                            Text {
                                text: "Arch Tools"
                                color: moduleFontColor
                                font.pixelSize: 14
                                font.family: "Fira Sans Semibold"
                            }

                            // ===== Arch Tools • RESOURCES (cloned from updatesGroup) =====
                            // ===== Arch Tools • RESOURCES (robusto nel ColumnLayout) =====
                            Rectangle {
                                id: resourcesGroup
                                // stile card come gli update
                                radius: 10
                                color: ThemePkg.Theme.surface(0.06)
                                border.color: moduleBorderColor
                                border.width: 1

                                // >>> chiave: lasciare che il ColumnLayout decida la larghezza <<<
                                Layout.fillWidth: true
                                // altezza dalla colonna interna (così non collassa mai a 0)
                                property int pad: 8
                                implicitHeight: resourcesCol.implicitHeight + pad * 2
                                visible: true
                                z: 1

                                // ===== poll script (immutato) =====
                                property var stats: ({
                                    cpu: { total: 0, per_core: [] },
                                    gpu: { name: "", total: 0, detail: [] },
                                    mem: { used_gb: 0, total_gb: 0, percent: 0 },
                                    disk:{ root_percent: 0, home_percent: 0 }
                                })

                                Timer {
                                    id: resTimer
                                    running: true; repeat: true; interval: 1500
                                    onTriggered: if (!resProc.running) resProc.running = true
                                }
                                // usa le stesse import/tipi che usi già negli update (Io.Process o Process)
                                Io.Process {
                                    id: resProc
                                    command: ["/bin/bash","-lc","$HOME/.config/hypr/scripts/resources-stat.sh"]
                                    stdinEnabled: false
                                    stdout: Io.StdioCollector {
                                        waitForEnd: true
                                        onStreamFinished: {
                                            try {
                                                const o = JSON.parse(text.trim());
                                                if (o && o.cpu && o.mem && o.disk) resourcesGroup.stats = o;
                                            } catch(e) { console.warn("resources json parse failed:", e, text); }
                                            finally { resProc.running = false }
                                        }
                                    }
                                    onExited: resProc.running = false
                                }

                                // ===== contenuto card =====
                                Column {
                                    id: resourcesCol
                                    anchors.fill: parent
                                    anchors.margins: resourcesGroup.pad
                                    spacing: 10

                                    Text {
                                        text: "Resources"
                                        color: moduleFontColor
                                        font.pixelSize: 14
                                        font.family: "Fira Sans Semibold"
                                    }

                                    GridLayout {
                                        id: resGrid
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        // metà card con minimo — calcolato sulla larghezza reale del Grid
                                        readonly property real cellW: Math.max(
                                            180, (width - columnSpacing) / 2
                                        )

                                        // pill come quelle dei pacchetti (stesso sfondo/bordo)
                                        component ResCell: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: resGrid.cellW
                                            Layout.minimumWidth: 160
                                            implicitWidth: 180
                                            implicitHeight: 64

                                            color: moduleColor
                                            border.color: moduleBorderColor
                                            border.width: 1
                                            radius: 12   // angoli meno arrotondati come richiesto

                                            property string title: ""
                                            property string value: ""
                                            property string tip: ""

                                            HoverHandler { id: hov }
                                            QQC2.ToolTip.visible: hov.hovered
                                            QQC2.ToolTip.delay: 0
                                            QQC2.ToolTip.timeout: 60000
                                            QQC2.ToolTip.text: tip

                                            // contenuto centrato
                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 24
                                                spacing: 6
                                                Text {
                                                    text: parent.parent.title
                                                    color: ThemePkg.Theme.withAlpha(moduleFontColor, 0.8)
                                                    font.pixelSize: 12
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: parent.parent.value
                                                    color: moduleFontColor
                                                    font.pixelSize: 20
                                                    font.bold: true
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // CPU
                                        ResCell {
                                            title: "CPU"
                                            value: Math.round(resourcesGroup.stats.cpu.total) + "%"
                                            tip: resourcesGroup.stats.cpu.per_core.length
                                                ? "Per-core:\n" + resourcesGroup.stats.cpu.per_core
                                                    .map((v,i)=>"C"+i+": "+Math.round(v)+"%").join("   ")
                                                : "Collecting per-core…"
                                        }
                                        // RAM (in GB come richiesto)
                                        ResCell {
                                            title: "RAM"
                                            value: resourcesGroup.stats.mem.used_gb.toFixed(1) + " GB"
                                            tip: "Used: " + resourcesGroup.stats.mem.used_gb.toFixed(1) +
                                                " / " + resourcesGroup.stats.mem.total_gb.toFixed(1) + " GB"
                                        }
                                        // GPU
                                        ResCell {
                                            title: "GPU"
                                            value: Math.round(resourcesGroup.stats.gpu.total) + "%"
                                            tip: (resourcesGroup.stats.gpu.detail && resourcesGroup.stats.gpu.detail.length)
                                                ? resourcesGroup.stats.gpu.detail
                                                    .map(d=>d.name+": "+Math.round(d.percent)+"%").join("\n")
                                                : (resourcesGroup.stats.gpu.name
                                                    ? resourcesGroup.stats.gpu.name+" total: "+
                                                    Math.round(resourcesGroup.stats.gpu.total)+"%"
                                                    : "No GPU data")
                                        }
                                        // DISK
                                        ResCell {
                                            title: "DISK"
                                            value: resourcesGroup.stats.disk.root_percent + "%"
                                            tip: "/: " + resourcesGroup.stats.disk.root_percent + "%\n" +
                                                "/home: " + resourcesGroup.stats.disk.home_percent + "%"
                                        }
                                    }
                                }
                            }


                            // ======================
                            // BLOCCO AGGIORNAMENTI
                            // ======================
                            Rectangle {
                                id: updatesGroup
                                radius: 10
                                color: ThemePkg.Theme.surface(0.06)
                                border.color: moduleBorderColor
                                border.width: 1

                                // padding e auto-size in base al contenuto
                                property int pad: 8
                                implicitWidth: updatesCol.implicitWidth + pad * 2
                                implicitHeight: updatesCol.implicitHeight + pad * 2

                                Column {
                                    id: updatesCol
                                    anchors.fill: parent
                                    anchors.margins: updatesGroup.pad
                                    spacing: 8

                                    // Totale (centrato)
                                    Rectangle {
                                        id: totalUpdatesBtn
                                        radius: 10
                                        height: 34
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: maUpdAll.containsMouse
                                            ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                            : moduleColor
                                        border.color: (updTotal > 0 ? ThemePkg.Theme.accent : moduleBorderColor)
                                        border.width: 1
                                        implicitWidth: totalUpdRow.implicitWidth + 16

                                        Row {
                                            id: totalUpdRow
                                            spacing: 8
                                            anchors.centerIn: parent
                                            Text {
                                                text: ""
                                                color: moduleFontColor
                                                font.pixelSize: 16
                                                font.family: "CaskaydiaMono Nerd Font"
                                            }
                                            Text {
                                                text: (updTotal || 0) + " updates"
                                                color: moduleFontColor
                                                font.pixelSize: 14
                                                font.family: "Fira Sans Semibold"
                                            }
                                        }

                                        MouseArea {
                                            id: maUpdAll
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    showPkgList("all")
                                                } else {
                                                    runScript(updatesAllScript)
                                                    updatesRecheckSoon.start()
                                                }
                                            }
                                        }

                                        ToolTip.visible: maUpdAll.containsMouse
                                        ToolTip.delay: 220
                                        ToolTip.text: "Update everything\nPacman: " + updPacman + " • AUR: " + updAur + " • Flatpak: " + updFlatpak +
                                                    (updLastTs ? ("\nLast check: " + updLastTs) : "")
                                    }

                                    // RIGA per gestore (tre pulsanti dentro il contenitore)
                                    Row {
                                        id: perManagerRow
                                        spacing: 8
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        // dimensioni uniformi per i 3 tile
                                        property int tileW: 92
                                        property int tileH: 56

                                        // Pacman
                                        Rectangle {
                                            width: perManagerRow.tileW
                                            height: perManagerRow.tileH
                                            radius: 10
                                            color: maUpdPac.containsMouse
                                                ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                                : moduleColor
                                            border.color: (updPacman > 0 ? ThemePkg.Theme.accent : moduleBorderColor)
                                            border.width: 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text {
                                                    text: updPacman
                                                    color: moduleFontColor
                                                    font.pixelSize: 16
                                                    font.family: "Fira Sans Semibold"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                Text {
                                                    text: "pacman"
                                                    color: moduleFontColor
                                                    font.pixelSize: 11
                                                    font.family: "Fira Sans Semibold"
                                                    opacity: 0.85
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            MouseArea {
                                                id: maUpdPac
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        showPkgList("pacman")
                                                    } else {
                                                        runScript(updatePacmanScript)
                                                        updatesRecheckSoon.start()
                                                    }
                                                }
                                            }
                                            ToolTip.visible: maUpdPac.containsMouse
                                            ToolTip.delay: 220
                                            ToolTip.text: "Update pacman only"
                                        }

                                        // AUR
                                        Rectangle {
                                            width: perManagerRow.tileW
                                            height: perManagerRow.tileH
                                            radius: 10
                                            color: maUpdAur.containsMouse
                                                ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                                : moduleColor
                                            border.color: (updAur > 0 ? ThemePkg.Theme.accent : moduleBorderColor)
                                            border.width: 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text {
                                                    text: updAur
                                                    color: moduleFontColor
                                                    font.pixelSize: 16
                                                    font.family: "Fira Sans Semibold"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                Text {
                                                    text: "AUR"
                                                    color: moduleFontColor
                                                    font.pixelSize: 11
                                                    font.family: "Fira Sans Semibold"
                                                    opacity: 0.85
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            MouseArea {
                                                id: maUpdAur
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        showPkgList("aur")
                                                    } else {
                                                        runScript(updateAurScript)
                                                        updatesRecheckSoon.start()
                                                    }
                                                }
                                            }
                                            ToolTip.visible: maUpdAur.containsMouse
                                            ToolTip.delay: 220
                                            ToolTip.text: "Update AUR only"
                                        }

                                        // Flatpak
                                        Rectangle {
                                            width: perManagerRow.tileW
                                            height: perManagerRow.tileH
                                            radius: 10
                                            color: maUpdFlat.containsMouse
                                                ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                                : moduleColor
                                            border.color: (updFlatpak > 0 ? ThemePkg.Theme.accent : moduleBorderColor)
                                            border.width: 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text {
                                                    text: updFlatpak
                                                    color: moduleFontColor
                                                    font.pixelSize: 16
                                                    font.family: "Fira Sans Semibold"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                Text {
                                                    text: "Flatpak"
                                                    color: moduleFontColor
                                                    font.pixelSize: 11
                                                    font.family: "Fira Sans Semibold"
                                                    opacity: 0.85
                                                    horizontalAlignment: Text.AlignHCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            MouseArea {
                                                id: maUpdFlat
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        showPkgList("flatpak")
                                                    } else {
                                                        runScript(updateFlatpakScript)
                                                        updatesRecheckSoon.start()
                                                    }
                                                }
                                            }
                                            ToolTip.visible: maUpdFlat.containsMouse
                                            ToolTip.delay: 220
                                            ToolTip.text: "Update Flatpak only"
                                        }
                                    }
                                }
                            }



                            // ====== Pulsanti originali ======
                            Row {
                                spacing: 8

                                // Change wallpaper
                                Rectangle {
                                    width: 36; height: 30
                                    radius: 10
                                    property bool hovered: false
                                    color: hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08) : moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: moduleFontColor
                                        font.pixelSize: 16
                                        font.family: "CaskaydiaMono Nerd Font"
                                    }
                                    MouseArea {
                                        id: maWall
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.hovered = true
                                        onExited:  parent.hovered = false
                                        onClicked: {
                                            if (switcher.shownOverlay === "wallpaper") {
                                                switcher.close();
                                            } else {
                                                switcher.open("wallpaper");
                                            }
                                        }

                                    }
                                    ToolTip.visible: maWall.containsMouse
                                    ToolTip.delay: 250
                                    ToolTip.text: "Change wallpaper"
                                }

                                // --- Toggle autolock / Hypridle ---
                                Rectangle {
                                    width: 36; height: 30
                                    radius: 10
                                    property bool hovered: false
                                    color: switcher.autolockDisabled
                                        ? (hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.danger, 0.85)
                                        : ThemePkg.Theme.withAlpha(ThemePkg.Theme.danger, 0.75))
                                    : (hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                        : moduleColor)
                                    border.color: moduleBorderColor
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: switcher.autolockDisabled ? "" : ""
                                        color: switcher.autolockDisabled ? ThemePkg.Theme.c15 : moduleFontColor

                                        font.pixelSize: 16
                                        font.family: "CaskaydiaMono Nerd Font"
                                    }
                                    MouseArea {
                                        id: maLock
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.hovered = true
                                        onExited:  parent.hovered = false
                                        onClicked: {
                                            runScript(toggleAutolockScript, "toggle")
                                            switcher.autolockDisabled = !switcher.autolockDisabled
                                            autolockRecheck.start()
                                        }
                                    }
                                    ToolTip.visible: maLock.containsMouse
                                    ToolTip.delay: 250
                                    ToolTip.text: switcher.autolockDisabled
                                        ? "Autolock is OFF (click to enable)"
                                        : "Autolock is ON (click to disable)"
                                }

                                // Open clipboard manager
                                Rectangle {
                                    width: 36; height: 30
                                    radius: 10
                                    property bool hovered: false
                                    color: hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08) : moduleColor
                                    border.color: moduleBorderColor
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: moduleFontColor
                                        font.pixelSize: 16
                                        font.family: "CaskaydiaMono Nerd Font"
                                    }
                                    MouseArea {
                                        id: maClip
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.hovered = true
                                        onExited:  parent.hovered = false
                                        onClicked: {
                                            Quickshell.execDetached(["qs","ipc","call","archtools","hide"])       // chiudi Arch Tools
                                            Quickshell.execDetached(["qs","ipc","call","cliphist","showAt","0"])  // apri Cliphist allineato in alto
                                        }

                                    }
                                    ToolTip.visible: maClip.containsMouse
                                    ToolTip.delay: 250
                                    ToolTip.text: "Open clipboard manager"
                                }
                            }
                        }
                    }
                }
            }

            // === Wallpaper Picker Overlay ===
            Component {
                id: wallpaperComp
                
                
                Item {
                    anchors.fill: parent
                    

                    

                    // ---- MODEL ----
                    ListModel { id: wallpapersModel }

                    // Elenco non ricorsivo da ~/Pictures/Wallpapers
                    property string listCmd: "find \"$HOME/Pictures/Wallpapers\" -follow -regextype posix-extended -type f -iregex \".*\\.(jpe?g|png|webp|bmp|gif|avif|heic)$\" -printf \"%P\\t%p\\n\" | LC_ALL=C sort"




                    // helper: quoting sicuro per bash (gestisce anche gli apostrofi nel path)
                    function shQuote(s) {
                        return "'" + String(s).replace(/'/g, "'\"'\"'") + "'";
                    }

                    function applyWallpaper(absPath) {
                        const cmd = "$HOME/.config/swaybg/wallpaper.sh " + shQuote(absPath);
                        setProc.exec(["bash", "-lc", cmd]);
                    }


                    Component.onCompleted: {
                        wallpapersModel.clear();
                        listProc.exec(["bash","-lc", listCmd]);
                    }

                    // ---- PROCESSES ----
                    Process {
                        id: listProc
                        stdout: SplitParser {
                            splitMarker: "\n"
                            onRead: (line) => {
                                if (!line || line.trim().length === 0) return;
                                const parts = line.split("\t");
                                if (parts.length < 2) return;
                                wallpapersModel.append({
                                    name: parts[0],
                                    path: parts[1],
                                    url: "file://" + parts[1]
                                });
                            }
                        }
                    }
                    Process {
                        id: setProc
                        onExited: function() { switcher.close(); }
                    }

                    // ---- OVERLAY LAYOUT ----
                    Rectangle {
                        id: panel
                        width:  Math.min(parent.width  * 0.85, 1200)
                        height: Math.min(parent.height * 0.80, 820)
                        anchors.centerIn: parent
                        radius: 14
                        color: workspaceInactiveColor
                        border.color: moduleBorderColor
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                spacing: 12

                                Text {
                                    text: "Choose wallpaper"
                                    color: moduleFontColor
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    radius: 8; width: 28; height: 28
                                    color: workspaceActiveColor
                                    border.color: moduleBorderColor
                                    Text { anchors.centerIn: parent; text: "✕"; color: moduleFontColor; font.pixelSize: 14 }
                                    MouseArea { anchors.fill: parent; onClicked: switcher.close(); hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                }

                            }
                            Flickable {
                                id: scroller
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                // evita “buco” a destra: mai meno largo dello scroller
                                contentWidth:  Math.max(grid.implicitWidth,  width)
                                contentHeight: grid.implicitHeight
                                interactive: true

                                ScrollBar.vertical: ScrollBar {
                                    id: vbar
                                    policy: ScrollBar.AsNeeded
                                    hoverEnabled: true
                                    implicitWidth: 10
                                    minimumSize: 0.08
                                    // attiva le transizioni quando si muove/hover/drag
                                    active: hovered || pressed || scroller.moving

                                    // binario (track)
                                    background: Rectangle {
                                        anchors.fill: parent
                                        radius: width/2
                                        color: moduleBorderColor
                                        border.color: moduleBorderColor
                                        opacity: vbar.active ? 1.0 : 0.7
                                    }

                                    // thumb (parte che scorre) con colore interattivo
                                    contentItem: Rectangle {
                                        radius: width/2
                                        border.width: 1
                                        border.color: moduleBorderColor
                                        color: moduleFontColor
                                    }
                                }


                                Grid {
                                    id: grid
                                    // parametri card
                                    property int cardW: 248
                                    spacing: 12

                                    // ancoriamo in alto a sinistra del contenuto
                                    anchors.left: parent.left
                                    anchors.top:  parent.top

                                    // colonne sulla larghezza reale dello scroller (meno un piccolo margine)
                                    columns: Math.max(1, Math.floor( (scroller.width - spacing) / (cardW + spacing) ))

                                    Repeater {
                                        model: wallpapersModel
                                        delegate: Item {
                                            width: grid.cardW
                                            height: 168 + 26
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 16
                                                color: workspaceInactiveColor
                                                border.color: moduleBorderColor
                                                border.width: 1
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                    source: "file:" + model.path
                                                    sourceSize.width: 1024
                                                    sourceSize.height: 1024
                                                }
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: 26
                                                    color: ThemePkg && ThemePkg.Theme
                                                        ? ThemePkg.Theme.withAlpha(workspaceActiveColor, 0.6)  // 60% opaco
                                                        : workspaceActiveColor
                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        verticalAlignment: Text.AlignVCenter
                                                        elide: Text.ElideRight
                                                        text: model.name
                                                        color: moduleColor
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: applyWallpaper(model.path)
                                            }
                                        }
                                    }
                                }
                            }



                        }
                    }
                }
            }


            // ----------------
            // Pannello principale
            // ----------------
            PanelWindow {
                id: panel
                color: "transparent"
                screen: delegateRoot.modelData

                anchors { top: true; left: true; right: true }
                implicitHeight: 47
                readonly property real scaleFactor: implicitHeight / 45
                margins { top: 0; left: 0; right: 0 }

                // ===== Global updates cache (always alive) =====
                // Vive sempre, anche a pannello/overlay chiuso.
                property int    updPacman: 0
                property int    updAur: 0
                property int    updFlatpak: 0
                property int    updTotal: 0
                property string updLastTs: ""
                property var    _updLastMs: 0
                property int    updatesMinIntervalMs: 5 * 60 * 1000   // 5 min

                // Boot-time updates fetch (parte all'avvio della barra)
                property string _updatesCheckCmdBoot: "$HOME/.config/hypr/scripts/updates-check.sh"
                Process {
                    id: updatesCheckProcBootGlobal
                    command: ["bash", "-lc", panel._updatesCheckCmdBoot]
                    stdout: StdioCollector { id: updatesCheckOutBootGlobal; waitForEnd: true }
                    running: true

                    onExited: function(exitCode, exitStatus) {
                        var raw = (updatesCheckOutBootGlobal.text || "").trim();
                        var start = raw.lastIndexOf("{");
                        var end   = raw.lastIndexOf("}");
                        var json  = (start !== -1 && end !== -1 && end > start) ? raw.slice(start, end + 1) : raw;

                        var pc = 0, aur = 0, fl = 0, tot = 0;
                        try {
                            var obj = JSON.parse(json);
                            pc  = Number(obj.pacman  || 0);
                            aur = Number(obj.aur     || 0);
                            fl  = Number(obj.flatpak || 0);
                            tot = Number(obj.total   || (pc + aur + fl));
                        } catch(e) {
                            pc = aur = fl = tot = 0;
                        }
                        panel.updPacman  = pc;
                        panel.updAur     = aur;
                        panel.updFlatpak = fl;
                        panel.updTotal   = tot;
                        panel.updLastTs  = Qt.formatDateTime(new Date(), "HH:mm");
                        panel._updLastMs = Date.now();
                    }
                }


                Rectangle {
                    id: barBg
                    anchors.fill: parent
                    color: "transparent"
                    radius: 0
                    border.color: moduleBorderColor
                    border.width: 0

                    property real barPadding: 16 * panel.scaleFactor

                    Row {
                        id: workspacesRow
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 * panel.scaleFactor }
                        spacing: 8 * panel.scaleFactor

                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                visible: modelData.monitor.id === Hyprland.monitorFor(screen).id
                                width: 30 * panel.scaleFactor
                                height: 30 * panel.scaleFactor
                                radius: 10 * panel.scaleFactor
                                color: modelData.active ? workspaceActiveColor : workspaceInactiveColor
                                border.color: moduleBorderColor
                                border.width: 1 * panel.scaleFactor

                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("workspace " + modelData.id) }

                                Text {
                                    text: modelData.id
                                    anchors.centerIn: parent
                                    color: modelData.active ? workspaceActiveFontColor : workspaceInactiveFontColor
                                    font.pixelSize: 13 * panel.scaleFactor
                                    font.family: "Fira Sans Semibold"
                                }
                            }
                        }

                        Text {
                            visible: Hyprland.workspaces.length === 0
                            text: "No workspaces"
                            color: workspaceActiveFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                        }
                    }

                    // System Tray
                    Rectangle{
                        id: trayButton
                        width: systemTrayWidget.width
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: notifyButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        SystemTray {
                            id: systemTrayWidget
                            bar: panel
                            scaleFactor: panel.scaleFactor
                            anchors { right: notifyButton.left; verticalCenter: parent.verticalCenter; rightMargin: 0 }
                        }
                    }

                    // Notifiche
                    Rectangle {
                        id: notifyButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: rightsidebarButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("notifications");
                                } else if (switcher.shownOverlay === "notifications") {
                                    switcher.close();
                                } else {
                                    switcher.swap("notifications");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    // Right Sidebar Button (Connessioni) — spostato a destra del tasto batteria
                    Rectangle {
                        id: rightsidebarButton
                        width: 70 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: batteryButton.visible ? batteryButton.left : logoutButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }


                        property string networkIcon: ""
                        property string volumeIcon: ""

                        Row {
                            anchors.centerIn: parent
                            spacing: 4 * panel.scaleFactor
                            Text {
                                text: rightsidebarButton.networkIcon + "  " + rightsidebarButton.volumeIcon
                                color: moduleFontColor
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("connection");
                                } else if (switcher.shownOverlay === "connection") {
                                    switcher.close();
                                } else {
                                    switcher.swap("connection");
                                }
                            }
                        }

                        // Nota: nmcliProcess è definito altrove nel tuo progetto
                        Timer { interval: 10000; running: true; repeat: true; onTriggered: nmcliProcess.exec(nmcliProcess.command) }


                        Connections {
                            target: Pipewire.defaultAudioSink
                            function onVolumeChanged() { rightsidebarButton.updateVolumeIcon() }
                            function onMuteChanged() { rightsidebarButton.updateVolumeIcon() }
                        }

                        Component.onCompleted: { nmcliProcess.exec(nmcliProcess.command); updateVolumeIcon() }
                    }

                    // === Batteria (fix percentuale + testo %) ===
                    Rectangle {
                        id: batteryButton
                        // larghezza dinamica: padding orizzontale + contenuto (icona + "%")
                        property real hpad: 10 * panel.scaleFactor
                        implicitWidth: contentRow.implicitWidth + hpad * 2
                        width: visible ? implicitWidth : 0

                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: visible ? 1 * panel.scaleFactor : 0
                        anchors { right: logoutButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        visible: UPower.displayDevice.ready
                                && UPower.displayDevice.isLaptopBattery
                                && UPower.displayDevice.isPresent

                        // === Stato ===
                        property var dev: UPower.displayDevice
                        property int  pctOverride: -1       // % da /sys o upower -i
                        property int  tteOverride: -1       // sec
                        property int  ttfOverride: -1       // sec

                        // Anti-flicker tooltip state
                        property bool _hovered: false
                        property bool _tipVisible: false
                        Timer { id: _tipShow; interval: 250; repeat: false; onTriggered: if (batteryButton._hovered) batteryButton._tipVisible = true }
                        Timer { id: _tipHide; interval: 160; repeat: false; onTriggered: if (!batteryButton._hovered) batteryButton._tipVisible = false }

                        // % da mostrare: se ho override -> uso quello; altrimenti prendo (eventuale) valore di UPower
                        property int shownPct: {
                            if (batteryButton.pctOverride >= 0) return batteryButton.pctOverride;
                            var p = Number(batteryButton.dev.percentage);
                            return (!isNaN(p) && p >= 0 && p <= 100) ? Math.round(p) : 0;
                        }

                        // Tempi (UPower con fallback)
                        property int tte: (dev.timeToEmpty && dev.timeToEmpty > 0) ? dev.timeToEmpty : (tteOverride >= 0 ? tteOverride : 0)
                        property int ttf: (dev.timeToFull  && dev.timeToFull  > 0) ? dev.timeToFull  : (ttfOverride >= 0 ? ttfOverride : 0)

                        property bool charging:    dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge
                        property bool discharging: dev.state === UPowerDeviceState.Discharging || dev.state === UPowerDeviceState.PendingDischarge

                        function glyphFor(p) {
                            if (p >= 95) return "";
                            if (p >= 75) return "";
                            if (p >= 55) return "";
                            if (p >= 35) return "";
                            return "";
                        }
                        function fmtTime(sec) {
                            if (!sec || sec <= 0) return "";
                            var h = Math.floor(sec / 3600);
                            var m = Math.floor((sec % 3600) / 60);
                            return h + " h " + (m < 10 ? "0" + m : m) + " min";
                        }

                        // === UI: icona + percentuale ===
                        Row {
                            id: contentRow
                            anchors.centerIn: parent
                            spacing: 6 * panel.scaleFactor
                            property bool low: (!batteryButton.charging && batteryButton.shownPct <= 15)

                            // icona batteria o fulmine se in carica
                            Text {
                                text: batteryButton.charging ? "" : batteryButton.glyphFor(batteryButton.shownPct)
                                color: contentRow.low ? ThemePkg.Theme.danger : moduleFontColor
                                font.pixelSize: 16 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }
                            // percentuale
                            Text {
                                text: batteryButton.shownPct + "%"
                                color: contentRow.low ? ThemePkg.Theme.danger : moduleFontColor
                                font.pixelSize: 14 * panel.scaleFactor
                                font.family: "Fira Sans Semibold"
                            }
                        }

                        MouseArea {
                            id: maBatt
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { batteryButton._hovered = true;  _tipHide.stop(); _tipShow.start(); }
                            onExited:  { batteryButton._hovered = false; _tipShow.stop(); _tipHide.start(); }
                        }

                        ToolTip.visible: batteryButton._tipVisible
                        ToolTip.delay: 0   // gestiamo noi il delay con _tipShow/_tipHide
                        ToolTip.text: {
                            const t = batteryButton.charging ? batteryButton.ttf : batteryButton.tte;
                            const tStr = batteryButton.fmtTime(t);
                            if (batteryButton.charging) {
                                return tStr ? ("Carica completa tra " + tStr + " (" + batteryButton.shownPct + "%)") : ("In carica (" + batteryButton.shownPct + "%)");
                            } else if (batteryButton.discharging) {
                                return tStr ? (tStr + " rimanenti (" + batteryButton.shownPct + "%)") : ("Batteria " + batteryButton.shownPct + "%");
                            } else {
                                return "Batteria " + batteryButton.shownPct + "%";
                            }
                        }

                        // === Lettura percentuale: /sys (capacity o now/full), poi upower -i ===
                        property string _pctCmd:
                            "for d in /sys/class/power_supply/*; do " +
                            "  [ -f \"$d/type\" ] || continue; " +
                            "  if grep -qi battery \"$d/type\"; then " +
                            "    if [ -r \"$d/capacity\" ]; then cat \"$d/capacity\"; exit 0; fi; " +
                            "    if [ -r \"$d/charge_now\" ] && [ -r \"$d/charge_full\" ]; then " +
                            "      awk 'BEGIN{now=$(<\"" + "\\$d" + "/charge_now\"); full=$(<\"" + "\\$d" + "/charge_full\"); if (full>0) printf \"%d\\n\", (now*100)/full}'; exit 0; fi; " +
                            "    if [ -r \"$d/energy_now\" ] && [ -r \"$d/energy_full\" ]; then " +
                            "      awk 'BEGIN{now=$(<\"" + "\\$d" + "/energy_now\"); full=$(<\"" + "\\$d" + "/energy_full\"); if (full>0) printf \"%d\\n\", (now*100)/full}'; exit 0; fi; " +
                            "  fi; " +
                            "done; " +
                            "dev=$(upower -e | grep -m1 battery || true); " +
                            "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/percentage/ {gsub(/%/,\"\",$2); gsub(/^ +/,\"\",$2); print int($2)}'"

                        property string _tteCmd:
                            "dev=$(upower -e | grep -m1 battery || true); " +
                            "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to empty/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"

                        property string _ttfCmd:
                            "dev=$(upower -e | grep -m1 battery || true); " +
                            "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to full/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"

                        Process {
                            id: batPctProc
                            command: ["bash","-lc", batteryButton._pctCmd]
                            stdout: StdioCollector { id: batPctOut; waitForEnd: true }
                            onExited: {
                                var s = (batPctOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n >= 0 && n <= 100) batteryButton.pctOverride = n;
                            }
                        }
                        Process {
                            id: batTteProc
                            command: ["bash","-lc", batteryButton._tteCmd]
                            stdout: StdioCollector { id: batTteOut; waitForEnd: true }
                            onExited: {
                                var s = (batTteOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n > 0) batteryButton.tteOverride = n;
                            }
                        }
                        Process {
                            id: batTtfProc
                            command: ["bash","-lc", batteryButton._ttfCmd]
                            stdout: StdioCollector { id: batTtfOut; waitForEnd: true }
                            onExited: {
                                var s = (batTtfOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n > 0) batteryButton.ttfOverride = n;
                            }
                        }

                        // Poll
                        Timer { interval: 20000; running: true; repeat: true; onTriggered: batPctProc.exec(["bash","-lc", batteryButton._pctCmd]) }
                        Timer { interval: 60000; running: true; repeat: true; onTriggered: { batTteProc.exec(["bash","-lc", batteryButton._tteCmd]); batTtfProc.exec(["bash","-lc", batteryButton._ttfCmd]); } }

                        Component.onCompleted: {
                            batPctProc.exec(["bash","-lc", batteryButton._pctCmd]);
                            batTteProc.exec(["bash","-lc", batteryButton._tteCmd]);
                            batTtfProc.exec(["bash","-lc", batteryButton._ttfCmd]);
                        }
                    }



                    // Power
                    Rectangle {
                        id: logoutButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: archButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("power");
                                } else if (switcher.shownOverlay === "power") {
                                    switcher.close();
                                } else {
                                    switcher.swap("power");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    // === Tasto Arch tra power e ora ===
                    Rectangle {
                        id: archButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: timeButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("arch");
                                } else if (switcher.shownOverlay === "arch") {
                                    switcher.close();
                                } else {
                                    switcher.swap("arch");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 16 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"
                        }
                    }

                    // Time (auto-width)
                    Rectangle{
                        id: timeButton
                        property real hpad: 16 * panel.scaleFactor
                        implicitWidth: timeDisplay.implicitWidth + hpad * 2
                        width: implicitWidth

                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 * panel.scaleFactor }

                        Text {
                            id: timeDisplay
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: timeButton.hpad
                            }
                            property string currentTime: ""
                            text: currentTime
                            color: moduleFontColor
                            font.pixelSize: 14 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"

                            Timer {
                                interval: 1000; running: true; repeat: true
                                onTriggered: {
                                    var now = new Date()
                                    timeDisplay.currentTime = Qt.formatTime(now, "hh:mm") + " - " + Qt.formatDate(now, "ddd dd MMM")
                                }
                            }

                            Component.onCompleted: {
                                var now = new Date()
                                currentTime = Qt.formatDate(now, "MMM dd") + " " + Qt.formatTime(now, "hh:mm:ss")
                            }
                        }
                    }
                }
            }

        }
    }
}
