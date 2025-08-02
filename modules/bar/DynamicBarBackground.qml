import QtQuick 2.15
import QtQuick.Shapes 1.15

/* CornerThingy mk2 - reusable fancy corner component */
component CornerThingyMk2 : Rectangle {
    // exposes geometry and colour properties
    property string cornerType: "left"        // "left" or "right"
    property int cornerWidth: 16
    property int cornerHeight: 40
    property color color: "#000000"

    width: cornerWidth
    height: cornerHeight
    color: "transparent"

    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: 0
            fillColor: corner.color
            startX: cornerType === "left" ? cornerWidth : 0
            startY: 0
            // Draw vertical edge
            PathLine { x: cornerType === "left" ? cornerWidth : 0; y: cornerHeight }
            // Arc to create curved outer edge
            PathArc {
                x: cornerType === "left" ? 0 : cornerWidth
                y: cornerHeight
                radiusX: cornerWidth
                radiusY: cornerHeight
                direction: PathArc.Counterclockwise
            }
            // Close the shape at top
            PathLine { x: cornerType === "left" ? 0 : cornerWidth; y: 0 }
            PathArc {
                x: cornerType === "left" ? cornerWidth : 0
                y: 0
                radiusX: cornerWidth
                radiusY: cornerHeight
                direction: PathArc.Counterclockwise
            }
        }
    }
}

/* DynamicBarBackground component that grows with module count */
Rectangle {
    id: root
    // number of modules currently in the bar
    property int moduleCount: 0
    // width of each module
    property int moduleWidth: 0
    // background colour for the bar
    property color bgColor: "#000000"
    // padding around the modules (constant)
    readonly property int padding: 20
    // width automatically adapts when moduleCount or moduleWidth change
    width: moduleCount * moduleWidth + padding
    color: "transparent"

    // main rectangle background
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: root.bgColor
    }

    // left fancy corner
    CornerThingyMk2 {
        anchors {
            left: backgroundRect.left
            verticalCenter: backgroundRect.verticalCenter
            // negative margin keeps the corner outside of the rectangle body
            leftMargin: -cornerWidth
        }
        cornerType: "left"
        cornerWidth: 16
        cornerHeight: backgroundRect.height
        color: root.bgColor
    }

    // right fancy corner
    CornerThingyMk2 {
        anchors {
            right: backgroundRect.right
            verticalCenter: backgroundRect.verticalCenter
            rightMargin: -cornerWidth
        }
        cornerType: "right"
        cornerWidth: 16
        cornerHeight: backgroundRect.height
        color: root.bgColor
    }

    // Example usage within a QuickShell file:
    /*
    Row {
        id: modulesRow
        spacing: 8
        // modules such as workspaces and system tray would be children here
    }

    DynamicBarBackground {
        moduleCount: modulesRow.children.length  // reactive binding
        moduleWidth: 40                          // width for each module
        bgColor: "#1a1a1a"                       // custom background colour
        anchors {
            left: parent.left
            verticalCenter: modulesRow.verticalCenter
        }
    }
    */
}
