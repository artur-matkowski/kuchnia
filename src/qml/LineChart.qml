import QtQuick
import QtQuick.Shapes

// One line, drawn from a ChartSeries. Used by the weather forecast and the hot water history.
//
// The series arrives in data space - x in milliseconds since the epoch, y in its own unit -
// and the mapping to pixels happens here, so a resize costs a repaint and not a round trip
// through C++. See src/app/Series.hpp.
//
// An empty series draws nothing and says so. It must not fall back to a flat line at zero:
// that is indistinguishable from a real reading and is exactly the guard the working
// agreement forbids.
Item {
	id: root

	// The ChartSeries gadget: .points, .xMin, .xMax, .yMin, .yMax.
	property var series: null
	property color stroke: Theme.accent
	property int decimals: 1
	property string unit: ""

	// Forces the vertical range open when the data is nearly flat, so a tank holding steady
	// does not render as noise magnified across the whole height.
	property real minimumSpan: 1.0

	readonly property bool hasData: series !== null && series.points !== undefined
	                                && series.points.length > 1

	readonly property real yLow: hasData ? Math.min(series.yMin, series.yMax - minimumSpan) : 0
	readonly property real yHigh: hasData ? Math.max(series.yMax, yLow + minimumSpan) : 0

	// Reads plot.width and plot.height, which is what makes the binding below re-evaluate on
	// a resize: QML records every property read during an evaluation, called functions
	// included, so the dependency does not have to be named anywhere.
	function _plot() {
		if (!hasData || plot.width <= 0 || plot.height <= 0)
			return []

		const points = series.points
		const xSpan = Math.max(1, series.xMax - series.xMin)
		const ySpan = Math.max(1e-6, yHigh - yLow)
		const out = []

		for (let i = 0; i < points.length; ++i) {
			out.push(Qt.point(
				(points[i].x - series.xMin) / xSpan * plot.width,
				plot.height - (points[i].y - yLow) / ySpan * plot.height))
		}
		return out
	}

	function _time(milliseconds) {
		return Qt.formatDateTime(new Date(milliseconds), "HH:mm")
	}

	Text {
		anchors.centerIn: parent
		visible: !root.hasData
		text: "no data"
		color: Theme.textDim
		font.pixelSize: 12
	}

	Column {
		anchors { left: parent.left; top: parent.top; bottom: axis.top }
		width: 36
		visible: root.hasData

		Text {
			text: root.yHigh.toFixed(root.decimals) + root.unit
			color: Theme.textDim
			font.pixelSize: 10
		}
		Item { width: 1; height: parent.height - 24 }
		Text {
			text: root.yLow.toFixed(root.decimals) + root.unit
			color: Theme.textDim
			font.pixelSize: 10
		}
	}

	Item {
		id: plot
		anchors { left: parent.left; leftMargin: 40; right: parent.right; top: parent.top; bottom: axis.top }
		clip: true

		Shape {
			anchors.fill: parent
			visible: root.hasData
			// The default renderer goes through the scene graph; nothing here rasterises on
			// the CPU, which matters on an image with no software fallback at all.
			ShapePath {
				strokeColor: root.stroke
				strokeWidth: 2
				fillColor: "transparent"
				capStyle: ShapePath.RoundCap
				joinStyle: ShapePath.RoundJoin
				PathPolyline { path: root.hasData ? root._plot() : [] }
			}
		}
	}

	Item {
		id: axis
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: 14
		visible: root.hasData

		Text {
			anchors.left: parent.left
			anchors.leftMargin: 40
			text: root.hasData ? root._time(root.series.xMin) : ""
			color: Theme.textDim
			font.pixelSize: 10
		}
		Text {
			anchors.right: parent.right
			text: root.hasData ? root._time(root.series.xMax) : ""
			color: Theme.textDim
			font.pixelSize: 10
		}
	}
}
