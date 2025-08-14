//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "modules/bar/"
import "modules/notifications" as Notifications
import Quickshell.Services.Notifications as NS
// in cima al file, insieme agli altri import
import "modules/overlays"


ShellRoot {
    id: root

    Loader {
        active: true
        sourceComponent: Bar {
        }
        Notifications.NotificationPopup {
            id: notifPopup
            server: notifServer
            screen: Quickshell.screens[0]   // oppure Quickshell.primaryScreen, o lo screen della tua Bar
        }


    }

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

        // IMPORTANTISSIMO: marca tutte le notifiche come "tracked"
        onNotification: function(n) { n.tracked = true }
    }

    // OSD volume: singola istanza. Il compositor sceglie il monitor attivo.
    VolumeOverlay { }

}

