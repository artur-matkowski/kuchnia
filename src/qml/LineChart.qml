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

	// The visible time range, in milliseconds since the epoch. Left at zero, the chart draws
	// the whole series - which is what the hot water history wants. The weather panel drives
	// them instead, and animating windowEnd is what compresses the forecast horizontally.
	property real windowStart: 0
	property real windowEnd: 0

	// DaylightBand gadgets: .from and .to, milliseconds. Drawn behind the line, so night is
	// the bare surface and day is washed.
	property var bands: []

	// Forces the vertical range open when the data is nearly flat, so a tank holding steady
	// does not render as noise magnified across the whole height.
	property real minimumSpan: 1.0

	readonly property bool hasData: series !== null && series.points !== undefined
	                                && series.points.length > 1

	readonly property real xLow: windowEnd > windowStart ? windowStart : (hasData ? series.xMin : 0)
	readonly property real xHigh: windowEnd > windowStart ? windowEnd : (hasData ? series.xMax : 0)

	// The vertical range is taken over the points inside the window and not over the whole
	// series: a day scaled against a week's extremes is a line that barely moves. It also
	// re-evaluates while the window animates, so the vertical range eases along with the
	// horizontal one instead of stepping when the transition ends.
	readonly property var range: _range()

	readonly property bool hasVisible: range.count > 1
	readonly property real yLow: range.low
	readonly property real yHigh: range.high

	function _range() {
		const empty = { count: 0, low: 0, high: 0 }
		if (!hasData)
			return empty

		const points = series.points
		let count = 0
		let low = Infinity
		let high = -Infinity

		for (let i = 0; i < points.length; ++i) {
			if (points[i].x < xLow || points[i].x > xHigh)
				continue
			++count
			low = Math.min(low, points[i].y)
			high = Math.max(high, points[i].y)
		}
		if (count === 0)
			return empty

		low = Math.min(low, high - minimumSpan)
		return { count: count, low: low, high: Math.max(high, low + minimumSpan) }
	}

	// Reads plot.width and plot.height, which is what makes the binding below re-evaluate on
	// a resize: QML records every property read during an evaluation, called functions
	// included, so the dependency does not have to be named anywhere.
	function _plot() {
		if (!hasVisible || plot.width <= 0 || plot.height <= 0)
			return []

		const points = series.points
		const xSpan = Math.max(1, xHigh - xLow)
		const ySpan = Math.max(1e-6, yHigh - yLow)
		const out = []

		for (let i = 0; i < points.length; ++i) {
			// One point beyond each edge is mapped too, so the line enters and leaves the frame
			// instead of stopping short of it. `plot` clips, so the overshoot is never seen.
			if (points[i].x < xLow && i + 1 < points.length && points[i + 1].x < xLow)
				continue
			if (points[i].x > xHigh && i > 0 && points[i - 1].x > xHigh)
				continue
			out.push(Qt.point(
				(points[i].x - xLow) / xSpan * plot.width,
				plot.height - (points[i].y - yLow) / ySpan * plot.height))
		}
		return out
	}

	// The format follows the width of the window rather than being fixed: a week labelled
	// HH:mm at both ends reads as a day, and a week labelled with the weekday alone reads as
	// the same weekday twice.
	function _time(milliseconds) {
		const hours = (xHigh - xLow) / 3600000
		const format = hours > 96 ? "ddd d MMM" : (hours > 36 ? "ddd HH:mm" : "HH:mm")
		return Qt.formatDateTime(new Date(milliseconds), format)
	}

	Text {
		anchors.centerIn: parent
		visible: !root.hasVisible
		text: "no data"
		color: Theme.textDim
		font.pixelSize: 12
	}

	Column {
		anchors { left: parent.left; top: parent.top; bottom: axis.top }
		width: 36
		visible: root.hasVisible

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

		Repeater {
			model: root.hasVisible ? root.bands : []

			Rectangle {
				readonly property real span: Math.max(1, root.xHigh - root.xLow)

				x: (modelData.from - root.xLow) / span * plot.width
				width: (modelData.to - modelData.from) / span * plot.width
				height: plot.height
				color: Theme.daylight
			}
		}

		Shape {
			anchors.fill: parent
			visible: root.hasVisible
			// The default renderer goes through the scene graph; nothing here rasterises on
			// the CPU, which matters on an image with no software fallback at all.
			ShapePath {
				strokeColor: root.stroke
				strokeWidth: 2
				fillColor: "transparent"
				capStyle: ShapePath.RoundCap
				joinStyle: ShapePath.RoundJoin
				PathPolyline { path: root.hasVisible ? root._plot() : [] }
			}
		}
	}

	Item {
		id: axis
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: 14
		visible: root.hasVisible

		Text {
			anchors.left: parent.left
			anchors.leftMargin: 40
			text: root.hasVisible ? root._time(root.xLow) : ""
			color: Theme.textDim
			font.pixelSize: 10
		}
		Text {
			anchors.right: parent.right
			text: root.hasVisible ? root._time(root.xHigh) : ""
			color: Theme.textDim
			font.pixelSize: 10
		}
	}
}
