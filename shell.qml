//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "modules/bar/"
import "modules/notifications" as Notifications
import Quickshell.Services.Notifications as NS
import "modules/overlays"
import "modules/theme" as ThemePkg
import "modules/cliphist" as QSMod


ShellRoot {
    id: root

    // --- Notification server UNICO ---
    NS.NotificationServer {
        id: notifServer
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true
        keepOnReload: true

        // ⚠️ RIMOSSO l'handler inline "onNotification: function(n) { ... }"
        // perché può non eseguire correttamente / generare warning.
    }

    // --- Marca tracked (se possibile) e fai anche da "canary" che gli eventi arrivano ---
    Connections {
        target: notifServer
        ignoreUnknownSignals: true
        function onNotification(n) {
            try { n.tracked = true } catch (e) {}
            // console.log("QS notif (onNotification):", n && n.summary)
        }
        function onNotificationAdded(n) {
            try { n.tracked = true } catch (e) {}
            // console.log("QS notif (onNotificationAdded):", n && n.summary)
        }
    }

    // --- Bar caricata via Loader (come avevi) ---
    Loader {
        active: true
        sourceComponent: Bar { }
    }

    // --- Popup notifiche: istanza diretta, come l'OSD del volume ---
    Notifications.NotificationPopup {
        id: notifPopup
        server: notifServer
    }

    // --- OSD volume: singola istanza. Il compositor sceglie il monitor attivo. ---
    VolumeOverlay { }
    QSMod.CliphistPopup {
        // offset per stare sotto la barra (adatta se la tua bar è più alta)
        topMarginPx: 48
    }
}
