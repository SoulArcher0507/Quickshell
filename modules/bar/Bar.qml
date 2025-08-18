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
import Quickshell.Services.UPower    // <-- aggiunto per batteria


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
                screen: delegateRoot.modelData
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                visible: (switcher.shownOverlay !== "") || (switcher.pendingIndex !== -1)

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
                    Component.onCompleted: autolockStatusProc.exec(["bash","-lc", switcher.autolockStatusCmd])

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
                    property string openClipboardScript:  "$HOME/.config/waybar/scripts/cliphist.sh"

                    // === Nuovi script aggiornamenti (li fornisco nel prossimo messaggio) ===
                    property string updatesCheckScript:   "$HOME/.config/hypr/scripts/updates-check.sh"
                    property string updatesAllScript:     "$HOME/.config/hypr/scripts/update-all.sh"
                    property string updatePacmanScript:   "$HOME/.config/hypr/scripts/update-pacman.sh"
                    property string updateAurScript:      "$HOME/.config/hypr/scripts/update-aur.sh"       // yay/AUR
                    property string updateFlatpakScript:  "$HOME/.config/hypr/scripts/update-flatpak.sh"

                    // Check real Hypridle status: exit 0 => running (autolock ON), non-zero => not running (autolock OFF)
                    property string autolockStatusCmd: "pgrep -x hypridle"
                    property int    autolockStatusPollMs: 3000

                    // true => autolock disabled (Hypridle OFF)
                    property bool autolockDisabled: false

                    // === Stato aggiornamenti ===
                    property int updPacman: 0
                    property int updAur: 0
                    property int updFlatpak: 0
                    property int updTotal: 0
                    property string updLastTs: ""

                    function runScript(path, args) {
                        if (!path || path.trim() === "") return;
                        var cmd = '"' + path + '"' + (args && args.length ? " " + args : "");
                        Hyprland.dispatch("exec " + cmd);
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
                        onTriggered: autolockStatusProc.start()
                    }
                    Timer {
                        id: autolockRecheck
                        interval: 350
                        repeat: false
                        onTriggered: autolockStatusProc.start()
                    }

                    // --- Update counts (robusto anche se lo script ancora non c'è) ---
                    property string _updatesCheckCmd: "([ -x \"$HOME/.config/hypr/scripts/updates-check.sh\" ] && \"$HOME/.config/hypr/scripts/updates-check.sh\") || echo '{\"pacman\":0,\"aur\":0,\"flatpak\":0,\"total\":0}'"

                    Process {
                        id: updatesCheckProc
                        command: ["bash", "-lc", _updatesCheckCmd]

                        // >>> AGGIUNTO: raccoglie l'output in una stringa
                        stdout: StdioCollector {
                            id: updatesCheckOut
                            waitForEnd: true
                        }

                        onExited: function(exitCode, exitStatus) {
                            var out = (updatesCheckOut.text || "").trim();

                            try {
                                var obj = JSON.parse(out);
                                updPacman  = obj.pacman  || 0;
                                updAur     = obj.aur     || 0;
                                updFlatpak = obj.flatpak || 0;
                                updTotal   = obj.total   || (updPacman + updAur + updFlatpak);
                            } catch (e) {
                                // fallback: prova a pescare 3-4 numeri dall'output
                                var m = out.match(/(\d+)[^\d]+(\d+)[^\d]+(\d+)(?:[^\d]+(\d+))?/);
                                if (m) {
                                    updPacman  = parseInt(m[1]);
                                    updAur     = parseInt(m[2]);
                                    updFlatpak = parseInt(m[3]);
                                    updTotal   = m[4] ? parseInt(m[4]) : (updPacman + updAur + updFlatpak);
                                } else {
                                    updPacman = updAur = updFlatpak = updTotal = 0;
                                }
                            }

                            var now = new Date();
                            updLastTs = Qt.formatTime(now, "hh:mm");
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
                        autolockStatusProc.start();
                        updatesCheckProc.exec(["bash","-lc", _updatesCheckCmd]);
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
                                text: "Arch tools"
                                color: moduleFontColor
                                font.pixelSize: 14
                                font.family: "Fira Sans Semibold"
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
                                        onClicked: runScript(changeWallpaperScript)
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
                                        onClicked: runScript(openClipboardScript)
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
