import QtQuick 2.15
import QtQuick.Shapes 1.15

// DynamicBarBackground: resizable background with fancy corners
Rectangle {
    id: root
    // Total number of modules displayed in the bar
    property int moduleCount: 0
    // Width of each module in pixels
    property int moduleWidth: 0
    // Background color for the bar
    property color bgColor: "#000000"

    // Extra width added to account for padding and corner width
    readonly property int padding: 20

    // Width updates automatically when moduleCount or moduleWidth change
    width: moduleCount * moduleWidth + padding
    color: "transparent"

    // Central rectangle providing the background fill
    Rectangle {
        id: backgroundRect
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: leftCorner.right  // leave space for left corner
            right: rightCorner.left // leave space for right corner
        }
        color: root.bgColor
    }

    // Left fancy corner instance
    CornerThingyMk2 {
        id: leftCorner
        cornerType: "left"
        cornerWidth: root.padding / 2
        cornerHeight: parent.height
        color: root.bgColor
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
    }

    // Right fancy corner instance
    CornerThingyMk2 {
        id: rightCorner
        cornerType: "right"
        cornerWidth: root.padding / 2
        cornerHeight: parent.height
        color: root.bgColor
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
    }

    // Example usage in a Quickshell Bar (commented):
    //
    // DynamicBarBackground {
    //     moduleCount: modulesRow.children.length    // bind to number of modules
    //     moduleWidth: 40                           // width of each module
    //     bgColor: "#1a1a1a"                        // background color
    //     anchors {
    //         top: parent.top
    //         bottom: parent.bottom
    //         left: parent.left
    //     }
    // }
}
