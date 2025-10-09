import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../theme" as ThemePkg

PopupWindow {
    id: popup

    // --- API esterna ---
    // Imposta da Bar.qml: a cosa si ancora (il bottone degli updates)
    required property Item anchorItem
    // Script da eseguire
    property string scriptPath: ""
    // Titolo (come nello screenshot)
    property string titleText: "Tutti gli aggiornamenti"
    // Usa un pty (consigliato per prompt sudo)
    property bool usePty: true

    function openWith(path, title) {
        scriptPath = path
        if (title && title.length) titleText = title
        open()
    }

    // --- Anchor e stile coerente col popup destro ---
    anchor {
        item: popup.anchorItem
        hEdge: PopupWindow.Right
        vEdge: PopupWindow.Bottom
        margin: 12
    }
    background: Rectangle {
        radius: 14
        color: ThemePkg.Theme.surface(0.10)
        border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12)
        border.width: 1
    }

    // Dimensioni: proporzionali al contenuto, con limiti e scroll
    implicitWidth: Math.min(900, contentCol.implicitWidth + 24)
    implicitHeight: Math.min(560, contentCol.implicitHeight + 24)

    // --- Contenuto ---
    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Header come il destro: titolo a sx, X a dx
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                id: header
                text: titleText
                font.pixelSize: 16
                font.bold: true
                color: ThemePkg.Theme.foreground
            }
            Item { Layout.fillWidth: true }

            ToolButton {
                text: "✕"
                onClicked: popup.close()
                background: Rectangle {
                    radius: 8
                    color: ThemePkg.Theme.surface(0.16)
                    border.color: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12)
                    border.width: 1
                }
            }
        }

        // Output scrollabile (tipo terminale)
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            TextArea {
                id: output
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

        // Riga input (per password sudo o comandi aggiuntivi)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: passwordMode ? "Password sudo…" : "Invia riga (Invio)"
                echoMode: passwordMode ? TextInput.Password : TextInput.Normal
                onAccepted: {
                    if (!proc.running) return
                    proc.write(text + "\n")
                    text = ""
                    if (passwordMode) passwordMode = false
                }
                background: Rectangle { color: ThemePkg.Theme.surface(0.06); radius: 10 }
            }

            Button {
                text: proc.running ? "Stop" : "Esegui"
                onClicked: {
                    if (proc.running) {
                        proc.signal(2) // SIGINT
                    } else {
                        startProc()
                    }
                }
            }
        }
    }

    // Stato interno
    property bool passwordMode: false

    // Processo
    Process {
        id: proc
        stdinEnabled: true
        // pty tramite 'script' (util-linux): gestisce bene i prompt di sudo
        command: popup.usePty
            ? [ "script", "-qefc", `bash -lc "${popup.scriptPath}"`, "/dev/null" ]
            : [ "bash", "-lc", popup.scriptPath ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => handleLine(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: (line) => handleLine(line)
        }

        onStarted: {
            output.text = `$ ${popup.scriptPath}\n`
            input.forceActiveFocus()
        }
        onExited: (code, status) => {
            output.append(`\n[Processo terminato] exit=${code}\n`)
            passwordMode = false
        }
    }

    function handleLine(line) {
        output.append(line + "\n")
        if (/assword.*: *$/i.test(line) || /\[sudo] password/i.test(line))
            passwordMode = true
        output.cursorPosition = output.length
    }

    function startProc() {
        output.text = ""
        passwordMode = false
        proc.start()
    }

    onOpened: startProc()
}
