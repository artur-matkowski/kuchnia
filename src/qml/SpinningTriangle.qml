import QtQuick
import QtQuick.Shapes

Item {
	id: root

	property real side: 400
	property int periodMs: 3000
	property color fill: "#f05a28"

	// An equilateral triangle's centroid sits a third of the way up, not halfway, so
	// the vertices are placed around the item's centre rather than inside its box.
	// Rotation is about transformOrigin, which is that centre - put the shape's
	// bounding box there instead and the triangle wobbles rather than spins.
	readonly property real h: side * Math.sqrt(3) / 2

	implicitWidth: side
	implicitHeight: side

	Shape {
		anchors.fill: parent

		ShapePath {
			// Negative disables stroking outright; 0 still costs a stroke pass.
			strokeWidth: -1
			fillColor: root.fill

			startX: root.width / 2
			startY: root.height / 2 - root.h * 2 / 3
			PathLine { x: root.width / 2 + root.side / 2; y: root.height / 2 + root.h / 3 }
			PathLine { x: root.width / 2 - root.side / 2; y: root.height / 2 + root.h / 3 }
			PathLine { x: root.width / 2;                 y: root.height / 2 - root.h * 2 / 3 }
		}
	}

	RotationAnimation on rotation {
		from: 0
		to: 360
		duration: root.periodMs
		loops: Animation.Infinite
		running: true
	}
}
