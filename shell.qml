//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "modules/bar/"

ShellRoot {
    id: root

    Loader {
        active: true
        sourceComponent: Bar {
        }
    }
}