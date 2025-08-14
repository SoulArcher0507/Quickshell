// modules/overlays/VolumeOverlay.qml
// OSD volume verticale, stile coerente con i moduli della barra.
// Mostra/si-nasconde automaticamente quando cambia il volume PipeWire.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import org.kde.layershell 1.0

// NOTA: questo componente va istanziato per ogni schermo (vedi shell.qml).
// È una finestra layer-shell ancorata a destra, senza riservare spazio (exclusiveZone=0).

PanelWindow {
    id: osd
    // --- posizione finestra (a destra, tutta l'altezza, margini) ---
    width: 84
    // l'altezza la determina il layer-shell agganciandosi top+bottom
    visible: true
    color: "transparent" // niente sfondo della finestra, lo gestiamo con il contenuto

    // Appare solo sul monitor attivo
    property bool isActiveMonitor: Hyprland.activeMonitor
                                   && screen
                                   && (Hyprland.activeMonitor.name === (screen.name || screen.model || ""))

    // Stato OSD
    property bool showing: false
    property real maxScale: 1.5    // supporto volume >100% (150%)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.mute)
    readonly property real rawVolume: sink ? sink.volume : 0.0
    readonly property real clampedVolume: Math.max(0, Math.min(rawVolume, maxScale))
    readonly property real volRatio: muted ? 0 : (clampedVolume / maxScale) // 0..1

    // Stile coerente con la barra (puoi cambiare qui se hai variabili globali)
    readonly property color moduleBg: "#222222"
    readonly property color moduleBorder: "#555555"
    readonly property color fillColor: "#6b4b3b"       // accento riempimento
    readonly property color trackColor: "#ffffff12"    // binario pallido
    readonly property color bubbleBg: "#1a1a1a"
    readonly property color bubbleFg: "#eeeeee"
    readonly property string fontFamily: "Fira Sans Semibold"


    // Auto-hide
    Timer {
        id: hideTimer
        interval: 1600
        repeat: false
        onTriggered: osd.showing = false
    }

    // Reagisci ai cambi volume/muto
    Connections {
        target: Pipewire.defaultAudioSink
        function onVolumeChanged() { osd.popup() }
        function onMuteChanged()   { osd.popup() }
    }

    function popup() {
        osd.showing = true
        hideTimer.restart()
    }

    // Impostazioni layer-shell native della finestra
    Component.onCompleted: {
        const w = QsWindow.window
        if (w) {
            w.aboveWindows = true              // sopra le altre finestre
            w.exclusiveZone = 0                // non riservare spazio
            try { w.setAnchor && w.setAnchor("right, top, bottom") } catch (_) {}
            try { w.setMargins && w.setMargins(24, 24, 24, 0) }      catch (_) {}
            try { w.keyboardInteractivity = 0 } catch (_) {}         // pass-through
            // Mostra all’avvio per 1s se vuoi un “ping” iniziale:
            // popup()
        }
    }

    // --- CONTENUTO OSD ---
    Rectangle {
        id: card
        anchors {
            right: parent.right
            rightMargin: 0
            verticalCenter: parent.verticalCenter
        }
        width: 84
        height: Math.min(480, parent.height - 48)
        radius: 12
        color: moduleBg
        border.color: moduleBorder
        border.width: 1

        // Pista + riempimento (slider verticale non interattivo)
        Rectangle {
            id: track
            anchors {
                top: parent.top; bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                topMargin: 24; bottomMargin: 24
            }
            width: 24
            radius: width/2
            color: trackColor
            border.color: moduleBorder
            border.width: 1

            // Riempimento proporzionale al volume (0..150%)
            Rectangle {
                id: fill
                width: parent.width
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                height: parent.height * osd.volRatio
                radius: width/2
                color: fillColor
            }

            // “bolla” icona appoggiata sul livello di riempimento
            Rectangle {
                id: bubble
                width: 36; height: 36
                radius: width/2
                color: bubbleBg
                border.color: moduleBorder
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - fill.height - height/2
                // clamp per non uscire dal binario
                onYChanged: {
                    if (y < -2) y = -2
                    if (y > parent.height - height + 2) y = parent.height - height + 2
                }

                Text {
                    anchors.centerIn: parent
                    text: osd.muted ? "" : (osd.rawVolume <= 0.5 ? "" : "")
                    color: bubbleFg
                    font.pixelSize: 16
                    font.family: "Fira Sans Semibold"
                }
            }
        }

        // Percentuale a fondo carta (opzionale, piccolo)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            color: bubbleFg
            font.family: fontFamily
            font.pixelSize: 11
            text: osd.muted ? "MUTO" : Math.round(osd.clampedVolume * 100) + "%"
            opacity: 0.8
        }
    }
}
