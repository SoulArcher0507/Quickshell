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

                    // Check real Hypridle status: exit 0 => running (autolock ON), non-zero => not running (autolock OFF)
                    property string autolockStatusCmd: "pgrep -x hypridle"
                    property int    autolockStatusPollMs: 3000

                    // true => autolock disabled (Hypridle OFF)
                    property bool autolockDisabled: false

                    function runScript(path, args) {
                        if (!path || path.trim() === "") return;
                        // quota SOLO il path, poi aggiunge gli argomenti
                        var cmd = '"' + path + '"' + (args && args.length ? " " + args : "");
                        Hyprland.dispatch("exec " + cmd);
                    }


                    // Quickshell.Io.Process: usa onExited per leggere exitCode
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
                    // Recheck shortly after toggle
                    Timer {
                        id: autolockRecheck
                        interval: 350
                        repeat: false
                        onTriggered: autolockStatusProc.start()
                    }
                    Component.onCompleted: autolockStatusProc.start()

                    Rectangle {
                        id: archPanel
                        radius: 10
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1
                        // stessa posizione di Connessioni/Notifiche
                        anchors { top: parent.top; right: parent.right; rightMargin: 16 }

                        // dimensioni guidate dal contenuto (niente anchors.fill sul contenuto)
                        width: Math.max(220, contentBox.implicitWidth + 24)
                        height: contentBox.implicitHeight + 24

                        Column {
                            id: contentBox
                            anchors { top: parent.top; left: parent.left; topMargin: 12; leftMargin: 12 }
                            spacing: 8

                            Text {
                                text: "Arch tools"
                                color: moduleFontColor
                                font.pixelSize: 14
                                font.family: "Fira Sans Semibold"
                            }

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
                                    // RED when autolock is DISABLED
                                    color: switcher.autolockDisabled
                                        ? (hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.danger, 0.85)
                                        : ThemePkg.Theme.withAlpha(ThemePkg.Theme.danger, 0.75))
                                    : (hovered ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)
                                        : moduleColor)
                                    border.color: moduleBorderColor
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    // closed lock when DISABLED
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
                                            runScript(toggleAutolockScript, "toggle")  // usa il tuo script con argomento
                                            switcher.autolockDisabled = !switcher.autolockDisabled  // feedback immediato (se hai già spostato lo stato in switcher)
                                            autolockRecheck.start()  // riallinea con lo stato reale (pgrep)
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
                                    color: hovered ? "#3a3a3a" : moduleColor
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

                    // Right Sidebar Button
                    Rectangle {
                        id: rightsidebarButton
                        width: 70 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors { right: logoutButton.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * panel.scaleFactor }

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

