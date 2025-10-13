import QtQuick
import QtQuick.Layouts
import "../../theme" as ThemePkg

Item {
    id: root

    // Passati da Bar.qml (calendarComp → Loader.onLoaded)
    property Item timeButton         // il rettangolo dell'ora
    property var  overlayWindow      // PanelWindow dell'overlay (QQuickWindow)

    // ===== SCHEMA COLORI con BINDING (legge direttamente dal timeButton) =====
    property color bgColor:     (timeButton && timeButton.color) ? timeButton.color
                              : ThemePkg.Theme.surface(1.0)
    property color borderColor: (timeButton && timeButton.border && timeButton.border.color) ? timeButton.border.color
                              : ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.12)

    function _extractTextColor() {
        if (!timeButton) return ThemePkg.Theme.foreground
        try {
            for (let i = 0; i < timeButton.children.length; ++i) {
                const ch = timeButton.children[i]
                if (ch && ch.text !== undefined && ch.color !== undefined) return ch.color
            }
        } catch (e) {}
        return ThemePkg.Theme.foreground
    }
    property color textColor: _extractTextColor()

    // accent / hover
    property color accentColor: ThemePkg.Theme.accent
    readonly property color hoverFill: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)

    readonly property var theme: ThemePkg.Theme

    // ===== Stato calendario =====
    property date today: new Date()
    property int  displayedYear:  today.getFullYear()
    property int  displayedMonth: today.getMonth()  // 0..11
    property date selectedDate:   new Date(today.getFullYear(), today.getMonth(), today.getDate())

    // ===== Formattazione header (dd/MM/yyyy con zeri) =====
    function pad2(n) { return n < 10 ? "0" + n : "" + n }
    function formatDMY(d) { return pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1) + "/" + d.getFullYear() }
    // usa il giorno selezionato se è nel mese visualizzato, altrimenti 01
    property date headerDate: (selectedDate.getFullYear() === displayedYear && selectedDate.getMonth() === displayedMonth)
                              ? selectedDate
                              : new Date(displayedYear, displayedMonth, 1)

    width: 340
    height: 320
    visible: true
    z: 99999
    clip: false
    property int  preferredWidth: 340
    property string fontFamily: "Fira Sans Semibold"

    // ===== Margini popup =====
    property int sideMargin: 16   // margine destro/sinistro dal bordo schermo
    property int topGap: 0        // distanza dal bordo superiore (match Arch Tools)

    // Utilità
    function buildGrid(y, m) {
        const first = new Date(y, m, 1)
        let dow = first.getDay(); if (dow === 0) dow = 7
        const daysPrev = dow - 1
        const start = new Date(y, m, 1 - daysPrev)
        const grid = []
        for (let i = 0; i < 42; i++) grid.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
        return grid
    }
    function isSameDate(a, b) { return a.getFullYear()===b.getFullYear() && a.getMonth()===b.getMonth() && a.getDate()===b.getDate() }
    function isSameMonth(d, y, m) { return d.getFullYear()===y && d.getMonth()===m }
    function prevMonth() { if (displayedMonth===0) { displayedMonth=11; displayedYear-- } else displayedMonth-- }
    function nextMonth() { if (displayedMonth===11) { displayedMonth=0; displayedYear++ } else displayedMonth++ }
    function goToday() { displayedYear=today.getFullYear(); displayedMonth=today.getMonth(); selectedDate=new Date(today.getFullYear(), today.getMonth(), today.getDate()) }

    // Window helpers
    function _win() { return overlayWindow ? overlayWindow : (root.Window ? root.Window.window : null) }

    // Posizionamento
    Component.onCompleted: Qt.callLater(positionPopup)

    Connections { target: overlayWindow; onWidthChanged: Qt.callLater(positionPopup); onHeightChanged: Qt.callLater(positionPopup) }
    Connections {
        target: timeButton
        onWidthChanged:  Qt.callLater(positionPopup)
        onHeightChanged: Qt.callLater(positionPopup)
        onXChanged:      Qt.callLater(positionPopup)
        onYChanged:      Qt.callLater(positionPopup)
    }

    function positionPopup() {
        const win = _win()
        if (!win) return

        // limita la larghezza se lo schermo è stretto
        var maxW = Math.max(260, win.width - sideMargin*2)
        var newW = Math.min(preferredWidth || 340, maxW)
        if (root.width !== newW) root.width = newW

        // Y: bordo inferiore del timeButton (poi clamp con topGap)
        var baseY = topGap
        if (timeButton) {
            try {
                var gp = timeButton.mapToGlobal(Qt.point(timeButton.width/2, timeButton.height))
                var lp = win.mapFromGlobal(gp.x, gp.y)
                baseY = lp.y
            } catch (e) {}
        }

        // X: allinea al bordo destro
        var desiredX = win.width - root.width - sideMargin

        // Clamp entro i bordi, ma con topGap minimo molto piccolo (come Arch Tools)
        root.x = Math.max(sideMargin, Math.min(desiredX, win.width - root.width - sideMargin))
        root.y = Math.max(topGap, Math.min(baseY,    Math.max(topGap, win.height - root.height - topGap)))
    }

    // ---------- UI ----------
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: bgColor
        border.color: borderColor
        border.width: 1
        layer.enabled: true
        layer.smooth: true
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Header (frecce ai lati, titolo centrato = dd/MM/yyyy)
            Item {
                Layout.fillWidth: true
                implicitHeight: 32

                Rectangle {
                    id: prevBtn
                    width: 28; height: 28; radius: 10
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: maPrev.containsMouse ? hoverFill : "transparent"
                    border.color: borderColor
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "◀"; color: textColor; font.family: fontFamily }
                    MouseArea { id: maPrev; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: prevMonth() }
                }

                Rectangle {
                    id: nextBtn
                    width: 28; height: 28; radius: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: maNext.containsMouse ? hoverFill : "transparent"
                    border.color: borderColor
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "▶"; color: textColor; font.family: fontFamily }
                    MouseArea { id: maNext; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nextMonth() }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: formatDMY(headerDate)
                    color: textColor
                    font.family: fontFamily
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    z: -1
                }
            }

            // Sotto-card calendario
            Rectangle {
                id: gridCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.topMargin: 2
                Layout.bottomMargin: 10
                radius: 10
                color: ThemePkg.Theme.surface(0.06)
                border.color: borderColor
                border.width: 1

                property int  pad: 8
                property int  colSpacing: 4
                property real cellW: (width - 2*pad - (6*colSpacing)) / 7

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: gridCard.pad
                    spacing: 6

                    // Header giorni (allineato alla griglia)
                    GridLayout {
                        id: dayHeader
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: gridCard.colSpacing
                        rowSpacing: 0

                        Repeater {
                            model: ["L","M","M","G","V","S","D"]
                            Rectangle {
                                Layout.preferredWidth: gridCard.cellW
                                Layout.preferredHeight: 18
                                color: "transparent"
                                border.width: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: ThemePkg.Theme.withAlpha(textColor, 0.8)
                                    font.pixelSize: 12
                                    font.family: fontFamily
                                }
                            }
                        }
                    }

                    // Griglia 6x7
                    GridLayout {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 4
                        columnSpacing: gridCard.colSpacing

                        property var days: buildGrid(displayedYear, displayedMonth)

                        Repeater {
                            model: grid.days.length
                            Rectangle {
                                readonly property date cellDate: grid.days[index]
                                readonly property bool inMonth:     isSameMonth(cellDate, displayedYear, displayedMonth)
                                readonly property bool isTodayCell: isSameDate(cellDate, today)
                                readonly property bool isSelected:  isSameDate(cellDate, selectedDate)

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                implicitWidth: 36
                                implicitHeight: 28
                                Layout.preferredWidth: gridCard.cellW
                                Layout.preferredHeight: 28
                                radius: 10

                                color: isSelected  ? accentColor
                                     : isTodayCell ? ThemePkg.Theme.withAlpha(accentColor, 0.18)
                                     : (maCell.hovered ? hoverFill : "transparent")

                                border.width: 1
                                border.color: inMonth ? borderColor : ThemePkg.Theme.withAlpha(borderColor, 0.75)

                                Text {
                                    anchors.centerIn: parent
                                    text: cellDate.getDate()
                                    color: isSelected ? bgColor
                                          : (inMonth ? textColor : ThemePkg.Theme.withAlpha(textColor, 0.45))
                                    font.pixelSize: 13
                                    font.family: fontFamily
                                }

                                HoverHandler { id: maCell }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: selectedDate = new Date(cellDate.getFullYear(), cellDate.getMonth(), cellDate.getDate())
                                }
                            }
                        }
                    }
                }
            }

            // Footer
            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 6
                Layout.bottomMargin: 2

                width: 64; height: 30; radius: 10
                color: maToday.containsMouse ? hoverFill : "transparent"
                border.color: borderColor
                border.width: 1
                Text { anchors.centerIn: parent; text: "Oggi"; color: textColor; font.pixelSize: 13; font.family: fontFamily }
                MouseArea { id: maToday; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: goToday() }
            }
        }
    }
}
