import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io as Io 
import "../theme" as ThemePkg
import Quickshell.Io


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
    readonly property color moduleBorderColor: hasTheme ? ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35) : "#505050"
    readonly property color moduleFontColor:   hasTheme ? ThemePkg.Theme.accent : "#7aa2f7"


    // ===== GEOMETRIA =====
    property int defaultTopMarginPx: 0   // se vuoi sotto la bar: metti qui l’altezza della bar (es. 48)
    property int topMarginPx: 0
    property int minListHeight: 180
    property int maxListHeight: 420
    property int minCardWidth: 360
    property int maxCardWidth: 560
    property int maxCardHeight: 680   

    property alias isOpen: win.visible
    property int contentMaxHeight: 420


    Io.IpcHandler {
        target: "cliphist"

        function show(): void {
            // chiudi Arch Tools e posiziona al margine “di default”
            topMarginPx = defaultTopMarginPx
            Quickshell.execDetached(["qs","ipc","call","archtools","hide"])
            win.visible = true
            listModel.reload()
            search.forceActiveFocus()
        }

        function showAt(px: int): void {
            // apertura con margine esplicito (usata dagli Arch Tools)
            topMarginPx = px
            Quickshell.execDetached(["qs","ipc","call","archtools","hide"])
            win.visible = true
            listModel.reload()
            search.forceActiveFocus()
        }

        function toggle(): void {
            if (win.visible) {
                win.visible = false
                return
            }
            // se stiamo aprendo da scorciatoia, forziamo sempre il posizionamento
            topMarginPx = defaultTopMarginPx
            Quickshell.execDetached(["qs","ipc","call","archtools","hide"])
            win.visible = true
            listModel.reload()
            search.forceActiveFocus()
        }


        function hide(): void   { win.visible = false }
        function opened(): bool { return win.visible }
    }


    function stripIdPrefix(s) {
        return String(s || "").replace(/^\s*\d+\s+/, "");
    }


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
        width:  card.width
        height: card.height
        focusable: true
        
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: topMarginPx; right: 12 }

        onVisibleChanged: if (visible) { listModel.reload(); search.forceActiveFocus(); }
        // facciamo chiudere con ESC anche se il focus non è sulla search
        Keys.onReleased: (e)=> {
            if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true }
        }

        Rectangle {
            id: card
            anchors.right: parent.right
            width:  Math.max(minCardWidth, Math.min(maxCardWidth, content.implicitWidth + 16))
            height: Math.min(maxCardHeight, content.implicitHeight + 16)   
            radius: 14
            color: bg
            border.color: moduleBorderColor
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
                        text: "Clipboard History"
                        color: moduleFontColor
                        font.pixelSize: 14
                        font.family: "Fira Sans Semibold"
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        id: clearAllBtn
                        Layout.alignment: Qt.AlignRight
                        visible: cliphistModel.count > 0
                        text: "Clear all"

                        // stesso look del Notifications "Clear all"
                        background: Rectangle {
                            radius: 8
                            color: ThemePkg.Theme.surface(0.06)
                            border.color: borderCol     // già definito nel file come bordo tenue
                        }
                        contentItem: Text {
                            text: clearAllBtn.text
                            color: ThemePkg.Theme.accent
                            font.pixelSize: 12
                            font.family: "Fira Sans Semibold"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            padding: 8
                        }

                        onClicked: confirmClear.open()
                    }

                }

                // Search
                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: "Search…"
                    color: fg
                    onTextChanged: listModel.applyFilter(text)
                    Keys.onReturnPressed: {
                        if (cliphistModel.count > 0) {
                            // copia il primo elemento attualmente visibile nella lista
                            const first = cliphistModel.get(0)
                            if (first && first.line) actions.copyItem(first.line)
                        }
                    }
                    Keys.onEscapePressed: win.visible = false
                }

                // Lista: contribuisce all'implicitHeight
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, root.contentMaxHeight)
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: cliphistModel

                    delegate: Rectangle {
                        id: row
                        width: list.width
                        color: "transparent"
                        radius: 8
                        border.width: 1
                        border.color: ThemePkg.Theme.withAlpha(moduleBorderColor, hovered ? 1.0 : 0.6)
                        implicitHeight: Math.max(24, textItem.implicitHeight + 12)

                        property bool hovered: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            // ==== NUMERIC BADGE (decrescente) ====
                            Rectangle {
                                id: badge
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Math.max(28, badgeText.implicitWidth + 10)
                                width: Layout.preferredWidth
                                height: 20
                                radius: 6
                                color: ThemePkg.Theme.surface(0.10)
                                border.color: moduleBorderColor
                                border.width: 1

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    // 1° = N, 2° = N-1, ... (N = cliphistModel.count)
                                    text: (cliphistModel ? (cliphistModel.count - index) : 0)
                                    color: moduleFontColor
                                    font.pixelSize: 12
                                }
                            }

                            // ==== TESTO DELL'ELEMENTO ====
                            Text {
                                id: textItem
                                Layout.fillWidth: true
                                text: stripIdPrefix(model.line)   // <— prima era: model.line
                                color: fg
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: row.hovered = true
                            onExited:  row.hovered = false
                            onClicked: actions.copyItem(model.line)
                        }
                    }


                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: ScrollBar.AsNeeded
                        hoverEnabled: true
                        implicitWidth: 10
                        minimumSize: 0.08
                        active: hovered || pressed || list.moving

                        // track
                        background: Rectangle {
                            anchors.fill: parent
                            radius: width/2
                            color: moduleBorderColor
                            border.color: moduleBorderColor
                            opacity: vbar.active ? 1.0 : 0.7
                        }

                        // thumb
                        contentItem: Rectangle {
                            radius: width/2
                            border.width: 1
                            border.color: moduleBorderColor
                            color: moduleFontColor
                        }
                    }

                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: `${cliphistModel.count} items`; color: ThemePkg.Theme.withAlpha(fg, 0.7) }
                    Item { Layout.fillWidth: true }
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
        property var _allItems: []
        property var _filtered: []

        function applyFilter(q) {
            const needle = (q || "").toLowerCase()
            root._filtered = !needle
                ? root._allItems
                : root._allItems.filter(l => l.toLowerCase().indexOf(needle) !== -1)
        }

        function refreshList() {
            // lista semplice (1 riga per item)
            procList.exec(["cliphist", "list"])
        }

        function reload() { procList.exec(["cliphist","list"]) }
    }

    Io.Process {
        id: procList
        stdout: Io.StdioCollector {
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
    }
                    
    Io.Process { id: copyProc }


    // ===== ACTIONS =====
    QtObject {
        id: actions
        function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
        function copyItem(line) {
            if (!line) return
            const cmd = "printf %s " + shQuote(line) + " | cliphist decode | wl-copy"
            copyProc.exec(["sh", "-lc", cmd])
            win.visible = false     // <- chiudi subito dopo aver lanciato la copia
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

    Timer {
        id: autoRefresh
        interval: 1500          // 1.5s; aumenta se vuoi meno frequente (es. 3000)
        repeat: true
        running: win.visible    // solo quando la finestra è aperta
        triggeredOnStart: true  // primo refresh immediato
        onTriggered: listModel.reload()
    }


    Dialog {
        id: confirmClear
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        title: "Clear entire history?"
        contentItem: Label {
            text: "This action will remove all items."
            color: fg; wrapMode: Text.Wrap; padding: 12
        }

        onAccepted: actions.wipeAll()
    }
}
