import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io as Io 
import "../theme" as ThemePkg



/* Popup Cliphist: overlay top-right, click fuori = chiudi */
Item {
    id: root

    // ===== THEME (stesso schema della Bar) =====
    readonly property bool hasTheme:
        !!ThemePkg && !!ThemePkg.Theme
        && (typeof ThemePkg.Theme.surface === "function")
        && (typeof ThemePkg.Theme.withAlpha === "function")

    readonly property color bg:        hasTheme ? ThemePkg.Theme.surface(0.10) : "#1e1e1e"
    readonly property color fg:        hasTheme ? ThemePkg.Theme.foreground     : "#eaeaea"
    readonly property color accent:    hasTheme ? ThemePkg.Theme.accent         : "#6aaeff"
    readonly property color borderCol: hasTheme ? ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12) : "#2a2a2a"

    // ===== GEOMETRIA =====
    property int topMarginPx: 48
    property int minListHeight: 180
    property int maxListHeight: 420
    property int minCardWidth: 360
    property int maxCardWidth: 560
    property int maxCardHeight: 680   

    // ===== SCRIM a schermo intero (chiude su click) =====
    PanelWindow {
        id: scrim
        visible: win.visible
        
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: win.visible = false
        }
        Keys.onReleased: (e)=> {
            if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true }
        }
        
    }

    // ===== CARD vera e propria =====
    PanelWindow {
        id: win
        visible: false
        
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: topMarginPx; right: 12 }

        onVisibleChanged: if (visible) listModel.reload()

        Rectangle {
            id: card
            anchors.right: parent.right
            width:  Math.max(minCardWidth, Math.min(maxCardWidth, content.implicitWidth + 16))
            height: Math.min(maxCardHeight, content.implicitHeight + 16)   // 👈 FIX: diamo un'altezza vera
            radius: 14
            color: bg
            border.color: borderCol
            border.width: 1

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: "Clipboard history"
                        color: fg
                        font.bold: true
                        font.pixelSize: 15
                    }
                    Item { Layout.fillWidth: true }
                    Button { text: "Clear all"; onClicked: confirmClear.open() }
                    Button { text: "Close"; onClicked: win.visible = false }
                }

                // Search
                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: "Cerca…"
                    color: fg
                    onTextChanged: listModel.applyFilter(text)
                }

                // Lista: contribuisce all'implicitHeight
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(maxListHeight, Math.max(minListHeight, contentHeight))
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: cliphistModel

                    delegate: Rectangle {
                        width: list.width
                        height: Math.max(40, txt.implicitHeight + 16)
                        radius: 10
                        color: hovered ? ThemePkg.Theme.withAlpha(fg, 0.06) : "transparent"
                        border.color: ThemePkg.Theme.withAlpha(fg, hovered ? 0.18 : 0.10)
                        border.width: 1
                        property bool hovered: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Label {
                                text: model.preview && model.preview.startsWith("[img]") ? "🖼️" : "📋"
                                color: fg
                                Layout.alignment: Qt.AlignTop
                            }

                            Text {
                                id: txt
                                Layout.fillWidth: true
                                text: model.preview
                                color: fg
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 6
                                Button { text: "Copy";  onClicked: actions.copyItem(model.line) }
                                Button { text: "Paste"; onClicked: actions.pasteItem(model.line) }
                                Button { text: "Del";   onClicked: actions.deleteItem(model.line) }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onClicked: actions.copyItem(model.line)
                        }
                    }

                    ScrollBar.vertical: ScrollBar { }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: `${cliphistModel.count} elementi`; color: ThemePkg.Theme.withAlpha(fg, 0.7) }
                    Item { Layout.fillWidth: true }
                    Button { text: "Refresh"; onClicked: listModel.reload() }
                }
            }
        }
    }

    // ===== MODEL & PROCESS (con alias Io.*) =====
    ListModel { id: cliphistModel }

    QtObject {
        id: listModel
        property var all: []

        function lineToEntry(line) {
            if (!line || !line.trim()) return null
            const tab = line.indexOf("\t")
            const id  = tab > 0 ? line.slice(0, tab) : line.split(/\s+/)[0]
            const preview = tab > 0 ? line.slice(tab + 1) : line
            return { id, preview, line }
        }
        function rebuildFiltered(q) {
            cliphistModel.clear()
            const needle = String(q||"").toLowerCase()
            for (let i=0; i<all.length; i++) {
                const e = all[i]
                if (!needle || e.preview.toLowerCase().includes(needle)) cliphistModel.append(e)
            }
        }
        function applyFilter(q) { rebuildFiltered(q) }
        function reload() { procList.exec(["cliphist","list"]) }
    }

    Io.Process { id: procList }                 // 👈 tipi con alias
    Io.StdioCollector {
        id: collector
        
        waitForEnd: true
        onStreamFinished: {
            const lines = String(text||"").split("\n").filter(l => l.trim().length)
            const items = []
            for (let i=0; i<lines.length; i++) {
                const e = listModel.lineToEntry(lines[i])
                if (e) items.push(e)
            }
            listModel.all = items
            listModel.rebuildFiltered(search.text)
        }
    }

    // ===== ACTIONS =====
    QtObject {
        id: actions
        function shQuote(s) { return "'" + String(s).replace(/'/g, "'\"'\"'") + "'" }
        function copyItem(line) {
            Io.execDetached(["sh","-lc", "printf %s " + shQuote(String(line)) + " | cliphist decode | wl-copy"])
        }
        function pasteItem(line) {
            const sh = `
printf %s ${shQuote(String(line))} | cliphist decode | wl-copy
if command -v wtype >/dev/null 2>&1; then wtype -M ctrl v -m ctrl; fi`
            Io.execDetached(["sh","-lc", sh])
        }
        function deleteItem(line) {
            Io.execDetached(["sh","-lc", "printf %s " + shQuote(String(line)) + " | cliphist delete"])
            listModel.reload()
        }
        function wipeAll() {
            Io.execDetached(["cliphist","wipe"])
            listModel.reload()
        }
    }

    Dialog {
        id: confirmClear
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        title: "Svuota intera cronologia?"
        contentItem: Label { text: "Questa azione rimuove TUTTI gli elementi."; color: fg; wrapMode: Text.Wrap; padding: 12 }
        onAccepted: actions.wipeAll()
    }
}
