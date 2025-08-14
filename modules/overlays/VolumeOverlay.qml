// modules/overlays/VolumeOverlay.qml
// OSD volume verticale centrato a destra.
// Pillola stretta con bordo, vuoto grigio (#cccccc) e riempimento azzurro (#4a9eff).
// Bubble senza icona, perfettamente sincronizzata con il fill.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets   // Scope, LazyLoader, Region

Scope {
    id: root

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }

    property bool shouldShowOsd: false
    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.shouldShowOsd = false
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio
        function onVolumeChanged() { root.shouldShowOsd = true; hideTimer.restart() }
        function onMuteChanged()   { root.shouldShowOsd = true; hideTimer.restart() }
        ignoreUnknownSignals: true
    }

    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            id: win
            // Finestrella overlay a DESTRA, tutta altezza; centriamo il contenuto dentro.
            anchors.right: true
            anchors.top: true
            anchors.bottom: true
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}   // click-through
            margins.right: 12

            // Larghezza = pillola + margine interno
            width: bg.width + 12

            // Valori volume/mute dal nodo .audio
            readonly property real volRaw:  Pipewire.defaultAudioSink?.audio.volume ?? 0
            readonly property bool muted:   Pipewire.defaultAudioSink?.audio.mute ?? false
            readonly property real volFrac: Math.max(0, Math.min(1, muted ? 0 : volRaw))

            // Palette coerente
            readonly property color bgColor:      "#222222"
            readonly property color bgBorder:     "#555555"
            readonly property color emptyColor:   "#cccccc"  // grigio repo
            readonly property color fillColor:    "#4a9eff"  // azzurro barra
            readonly property color bubbleBg:     "#1a1a1a"
            readonly property color bubbleBorder: "#555555"

            // ---- Pillola centrata verticalmente nella finestra a piena altezza ----
            Rectangle {
                id: bg
                width: 23
                height: 300
                radius: 12
                color: win.bgColor
                border.color: win.bgBorder
                border.width: 1

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter  // << centro reale

                // Barra interna
                Item {
                    id: bar
                    anchors {
                        right: parent.right
                        rightMargin: 7
                        top: parent.top
                        bottom: parent.bottom
                        topMargin: 10
                        bottomMargin: 10
                    }
                    width: 8

                    // Parte "vuota" (sopra) grigia
                    Rectangle {
                        id: empty
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: parent.height * (1 - win.volFrac)
                        radius: width / 2
                        color: win.emptyColor
                        border.color: win.bgBorder
                        border.width: 1
                        antialiasing: true
                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.InOutQuad } }
                    }

                    // Riempimento azzurro (sotto)
                    Rectangle {
                        id: fill
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: parent.height * win.volFrac
                        radius: width / 2
                        color: win.fillColor
                        border.color: win.bgBorder
                        border.width: 1
                        antialiasing: true
                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.InOutQuad } }
                    }

                    // Bubble: segue esattamente il bordo tra empty e fill (niente Behavior separato)
                    Rectangle {
                        id: bubble
                        width: 16; height: 16
                        radius: width / 2
                        color: win.bubbleBg
                        border.color: win.bubbleBorder
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: empty.height - height/2
                        antialiasing: true
                    }
                }
            }
        }
    }
}
