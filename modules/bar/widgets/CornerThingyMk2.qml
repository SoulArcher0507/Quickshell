import QtQuick 2.15
import QtQuick.Shapes 1.15

// CornerThingy mk2: draws a single curved corner
Rectangle {
    id: root
    // "left" or "right" orientation determines which side the corner faces
    property string cornerType: "right"
    // Width of the corner graphic
    property int cornerWidth: 20
    // Height of the corner graphic
    property int cornerHeight: 20
    // Fill color of the corner
    property color color: "#ffffff"

    width: cornerWidth
    height: cornerHeight
    color: "transparent"

    // Shape paints a quarter ellipse depending on cornerType
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: 0
            fillColor: root.color

            // Start from the outer top edge depending on orientation
            PathMove { x: root.cornerType === "left" ? 0 : root.cornerWidth; y: 0 }
            // Drop straight down along the outer edge
            PathLine { x: root.cornerType === "left" ? 0 : root.cornerWidth; y: root.cornerHeight }
            // Move across the bottom edge
            PathLine { x: root.cornerType === "left" ? root.cornerWidth : 0; y: root.cornerHeight }
            // Draw curved corner back to the starting point
            PathArc {
                x: root.cornerType === "left" ? 0 : root.cornerWidth
                y: 0
                radiusX: root.cornerWidth
                radiusY: root.cornerHeight
                direction: PathArc.Counterclockwise
            }
            closed: true
        }
    }
}
