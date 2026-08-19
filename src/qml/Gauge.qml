import QtQuick
import QtQuick.Shapes

// An arc from minimum to maximum with the reading in the middle.
//
// Draws its needle at the minimum when there is no reading, but the number reads "--" rather
// than a temperature: a gauge parked at the bottom of its scale is a plausible measurement,
// and the panel's status badge is too far away to be read as a correction to it.
Item {
	id: root

	property real value: 0
	property real minimum: 0
	property real maximum: 100
	property bool valid: true
	property string unit: ""
	property color arc: Theme.hot

	readonly property real _fraction: Math.max(0, Math.min(1,
		(value - minimum) / Math.max(1e-6, maximum - minimum)))

	readonly property real _radius: Math.min(width, height) * 0.42
	readonly property real _startAngle: 140
	readonly property real _sweep: 260

	Shape {
		anchors.fill: parent

		ShapePath {
			strokeColor: Theme.border
			strokeWidth: 10
			fillColor: "transparent"
			capStyle: ShapePath.RoundCap
			PathAngleArc {
				centerX: root.width / 2
				centerY: root.height / 2
				radiusX: root._radius
				radiusY: root._radius
				startAngle: root._startAngle
				sweepAngle: root._sweep
			}
		}

		ShapePath {
			strokeColor: root.arc
			strokeWidth: 10
			fillColor: "transparent"
			capStyle: ShapePath.RoundCap
			PathAngleArc {
				centerX: root.width / 2
				centerY: root.height / 2
				radiusX: root._radius
				radiusY: root._radius
				startAngle: root._startAngle
				sweepAngle: root._sweep * (root.valid ? root._fraction : 0)
			}
		}
	}

	Column {
		anchors.centerIn: parent
		spacing: 2

		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: root.valid ? root.value.toFixed(1) + root.unit : "--"
			color: root.valid ? Theme.text : Theme.textDim
			font.pixelSize: Math.max(14, root._radius * 0.5)
			font.bold: true
		}
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: root.minimum.toFixed(0) + root.unit + " - " + root.maximum.toFixed(0) + root.unit
			color: Theme.textDim
			font.pixelSize: 10
		}
	}
}
