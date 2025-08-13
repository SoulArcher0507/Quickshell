import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root
    property int margin: 16
    anchors.fill: parent
    color: "#222222"
    radius: 8
    border.color: "#555555"
    border.width: 1
    implicitHeight: content.implicitHeight + margin * 2

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 16

        Rectangle {
            id: dndButton
            Layout.fillWidth: true
            height: 30
            radius: 6
            color: Notifications.doNotDisturb ? "#444444" : "#333333"
            border.color: "#555555"

            Text {
                anchors.centerIn: parent
                text: Notifications.doNotDisturb ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Fira Sans Semibold"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
            }
        }

        ListView {
            id: notificationList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: Notifications.notifications
            spacing: 8

            delegate: Rectangle {
                width: notificationList.width
                radius: 6
                color: "#333333"
                border.color: "#555555"
                implicitHeight: bodyText.paintedHeight + titleText.paintedHeight + 16

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        id: titleText
                        text: model.summary
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        id: bodyText
                        text: model.body
                        color: "#dddddd"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
