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

	// A vertical range the data does not get a vote on. NaN, the default, means the range is
	// taken from the points inside the window as it always was. A percentage that rescales
	// itself is read wrong from across the room: 40% at the top of the frame looks like a
	// downpour, and the only thing saying otherwise is a label too small to read from there.
	property real fixedLow: NaN
	property real fixedHigh: NaN

	// Wide enough for the widest label the range can produce, so the line never starts under
	// its own axis.
	readonly property real _gutter: Theme.fontLabel * 3.2

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

		// count stays the number of points inside the window even when the range is fixed:
		// it is what hasVisible - and therefore "no data" - is decided on, and a fixed range
		// must not turn an empty window into a frame with axes and nothing in it.
		if (!isNaN(fixedLow))
			low = fixedLow
		if (!isNaN(fixedHigh))
			high = fixedHigh

		// minimumSpan opens the range away from whichever end was fixed. A chart pinned to
		// zero and given a forecast of no rain at all would otherwise answer with an axis of
		// negative millimetres - which is not a wrong-looking chart, it is a plausible one.
		if (isNaN(fixedLow))
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
		// A day is the interesting case: HH:mm at both ends of a 24 hour window prints the same
		// time twice, which reads as a chart that is not moving.
		const format = hours > 96 ? "ddd d MMM" : (hours > 12 ? "ddd HH:mm" : "HH:mm")
		return Qt.formatDateTime(new Date(milliseconds), format)
	}

	Text {
		anchors.centerIn: parent
		visible: !root.hasVisible
		text: "no data"
		color: Theme.textDim
		font.pixelSize: Theme.fontBody
	}

	// The two ends of the vertical range, anchored to the corners rather than spaced apart
	// inside a Column: a spacer sized against the font is one type-scale change away from
	// pushing the lower label out of the frame.
	Item {
		anchors { left: parent.left; top: parent.top; bottom: axis.top }
		width: root._gutter
		visible: root.hasVisible

		Text {
			anchors { left: parent.left; top: parent.top }
			text: root.yHigh.toFixed(root.decimals) + root.unit
			color: Theme.text
			font.pixelSize: Theme.fontLabel
			font.bold: true
		}
		Text {
			anchors { left: parent.left; bottom: parent.bottom }
			text: root.yLow.toFixed(root.decimals) + root.unit
			color: Theme.text
			font.pixelSize: Theme.fontLabel
			font.bold: true
		}
	}

	Item {
		id: plot
		anchors { left: parent.left; leftMargin: root._gutter + Theme.gap
		          right: parent.right; top: parent.top; bottom: axis.top }
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
				strokeWidth: 3
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
		height: Theme.fontLabel + 6
		visible: root.hasVisible

		Text {
			anchors.left: parent.left
			anchors.leftMargin: root._gutter + Theme.gap
			text: root.hasVisible ? root._time(root.xLow) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontLabel
		}
		Text {
			anchors.right: parent.right
			text: root.hasVisible ? root._time(root.xHigh) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontLabel
		}
	}
}
