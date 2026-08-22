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

	// The series as two flat arrays of plain numbers, refilled only when the series itself
	// changes. `series.points` is a QVariantList of QPointF, and reading an element through it
	// materialises a value-type wrapper every time; the window animates, so the loops below run
	// on every frame of a span change and must not touch it. See docs/scene.md.
	readonly property var _flat: _flatten()

	readonly property bool hasData: _flat.xs.length > 1

	readonly property real xLow: windowEnd > windowStart ? windowStart : (hasData ? series.xMin : 0)
	readonly property real xHigh: windowEnd > windowStart ? windowEnd : (hasData ? series.xMax : 0)

	// Where the window falls in the series: `first` is the first point at or after xLow, `last`
	// the first one past xHigh. Everything below works on that slice and not on the whole
	// series, which is what keeps a 24 hour window off the other seven days of the forecast.
	readonly property var _window: _bracket()

	// The vertical range is taken over the points inside the window and not over the whole
	// series: a day scaled against a week's extremes is a line that barely moves. It also
	// re-evaluates while the window animates, so the vertical range eases along with the
	// horizontal one instead of stepping when the transition ends.
	readonly property var range: _range()

	readonly property bool hasVisible: range.count > 1
	readonly property real yLow: range.low
	readonly property real yHigh: range.high

	function _flatten() {
		const points = (series !== null && series.points !== undefined) ? series.points : []
		const xs = new Array(points.length)
		const ys = new Array(points.length)
		for (let i = 0; i < points.length; ++i) {
			xs[i] = points[i].x
			ys[i] = points[i].y
		}
		return { xs: xs, ys: ys }
	}

	// The first index whose x is at or after `at`. The points must be ascending in x, and both
	// producers are: the archive orders by its time bucket, and a forecast is zipped against an
	// ascending hourly.time. A series that stopped being ascending would draw a line truncated
	// at the first step backwards, with nothing anywhere saying so.
	function _seek(xs, at) {
		let lo = 0
		let hi = xs.length
		while (lo < hi) {
			const mid = (lo + hi) >> 1
			if (xs[mid] < at)
				lo = mid + 1
			else
				hi = mid
		}
		return lo
	}

	function _bracket() {
		if (!hasData)
			return { first: 0, last: 0 }

		const xs = _flat.xs
		const first = _seek(xs, xLow)

		// _seek stops at the first x at or after xHigh, and a point landing exactly on the far
		// edge is inside the window.
		let last = _seek(xs, xHigh)
		while (last < xs.length && xs[last] <= xHigh)
			++last

		return { first: first, last: last }
	}

	function _range() {
		const empty = { count: 0, low: 0, high: 0 }
		if (!hasData)
			return empty

		const ys = _flat.ys
		const first = _window.first
		const last = _window.last
		const count = last - first
		if (count === 0)
			return empty

		let low = Infinity
		let high = -Infinity
		for (let i = first; i < last; ++i) {
			low = Math.min(low, ys[i])
			high = Math.max(high, ys[i])
		}

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

		const xs = _flat.xs
		const ys = _flat.ys
		const xSpan = Math.max(1, xHigh - xLow)
		const ySpan = Math.max(1e-6, yHigh - yLow)

		// One point beyond each edge is mapped too, so the line enters and leaves the frame
		// instead of stopping short of it. `plot` clips, so the overshoot is never seen.
		const from = Math.max(0, _window.first - 1)
		const to = Math.min(xs.length - 1, _window.last)

		const out = []
		for (let i = from; i <= to; ++i)
			out.push(Qt.point(
				(xs[i] - xLow) / xSpan * plot.width,
				plot.height - (ys[i] - yLow) / ySpan * plot.height))
		return out
	}

	// The grid step: the smallest of 1, 2 or 5 times a power of ten that leaves about five
	// divisions across the range, so a line lands on a value that can be named - every ten
	// degrees across the tank's range, every twenty percent across a cloud cover chart.
	function _step(span) {
		const raw = span / 5
		const magnitude = Math.pow(10, Math.floor(Math.log10(raw)))
		const steps = [1, 2, 5, 10]
		for (let i = 0; i < steps.length; ++i)
			if (raw <= steps[i] * magnitude)
				return steps[i] * magnitude
		return 10 * magnitude
	}

	// Every round value strictly inside the vertical range. The range follows the window and
	// the window animates, so a line can arrive or leave at an edge part-way through a span
	// change - which is the price of lines that mean something over lines at fixed fractions.
	function _levels() {
		const span = yHigh - yLow
		if (!hasVisible || span <= 0)
			return []

		const step = _step(span)
		const out = []
		for (let v = Math.ceil(yLow / step) * step; v < yHigh; v += step)
			if (v > yLow)
				out.push(v)
		return out
	}

	// Local midnight inside the window. Stepped with setDate and never by adding 86400000: the
	// clock changes twice a year, and a day of fixed milliseconds puts every line after the
	// change an hour off the midnight it claims to be - which reads as a forecast that is
	// wrong rather than as a grid that is.
	function _days() {
		if (!hasVisible)
			return []

		const out = []
		const at = new Date(xLow)
		at.setHours(24, 0, 0, 0)
		while (at.getTime() < xHigh) {
			out.push(at.getTime())
			at.setDate(at.getDate() + 1)
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

		// The grid, over the daylight wash and under the line. Both models answer empty while the
		// chart has nothing to draw, which is what keeps a window past the end of the forecast
		// reading as "no data" rather than as a frame with nothing happening in it.
		Repeater {
			model: root._levels()

			Rectangle {
				readonly property real span: Math.max(1e-6, root.yHigh - root.yLow)

				y: Math.round(plot.height - (modelData - root.yLow) / span * plot.height)
				width: plot.width
				height: 1
				color: Theme.grid
			}
		}

		Repeater {
			model: root._days()

			Rectangle {
				readonly property real span: Math.max(1, root.xHigh - root.xLow)

				x: Math.round((modelData - root.xLow) / span * plot.width)
				width: 1
				height: plot.height
				color: Theme.grid
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
