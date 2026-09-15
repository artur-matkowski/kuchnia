import QtQuick
import QtQuick.Shapes
import Kuchnia

// N lines, drawn from N ChartSeries, sharing one window and one vertical axis. Used where
// LineChart's one line is not enough but the axis still is - three cloud bands charted against
// the same 0-100% scale.
//
// LineChart.qml stays untouched by this file on purpose: its four callers need none of the
// generalisation below, and re-verifying its hardened single-series logic against a shape it
// never has to draw is a cost this file exists to avoid. Everything here mirrors LineChart's
// naming and invariants - see docs/charts.md - generalised only where a second series forces it.
Item {
	id: root

	// [{ data: <ChartSeries>, stroke: <color> }, ...]. `data` is a plain object-literal key and
	// has nothing to do with Item.data, the reserved default-children property.
	property var series: []

	property int decimals: 1
	property string unit: ""

	// Same property, same reason as LineChart's: two reals assigned one after the other would
	// be read once with an end and no start. See ChartCard.qml.
	property point window: Qt.point(0, 0)

	// DaylightBand gadgets: .from and .to, milliseconds.
	property var bands: []

	property real minimumSpan: 1.0
	property real fixedLow: NaN
	property real fixedHigh: NaN

	readonly property real _gutter: Theme.fontBody * 3.2

	// One {xs, ys} per series[i], rebuilt only when `series` itself re-evaluates - on
	// Weather.forecastChanged, once per REST poll, never per frame. See docs/scene.md.
	readonly property var _flat: _flattenAll()

	readonly property bool hasData: _flat.some(f => f.xs.length > 1)

	readonly property real xLow:
		root.window.y > root.window.x ? root.window.x : (hasData ? _dataXMin() : 0)
	readonly property real xHigh:
		root.window.y > root.window.x ? root.window.y : (hasData ? _dataXMax() : 0)

	// One bracket per series, which the range and every line are taken over.
	readonly property var _windows: _flat.map(f => _bracket(f.xs))

	readonly property var range: _range()

	readonly property bool hasVisible: range.count > 1
	readonly property real yLow: range.low
	readonly property real yHigh: range.high

	function _flatten() {
		if (Trace.enabled) Trace.begin("overlay.flatten")
		try {
			return _flattenAll()
		} finally {
			if (Trace.enabled) Trace.end("overlay.flatten")
		}
	}

	function _flattenOne(data) {
		const points = (data !== null && data !== undefined && data.points !== undefined)
			? data.points : []
		const xs = new Array(points.length)
		const ys = new Array(points.length)
		for (let i = 0; i < points.length; ++i) {
			xs[i] = points[i].x
			ys[i] = points[i].y
		}
		return { xs: xs, ys: ys }
	}

	function _flattenAll() {
		return root.series.map(entry => _flattenOne(entry.data))
	}

	function _dataXMin() {
		let min = Infinity
		for (const entry of root.series)
			if (entry.data && entry.data.points && entry.data.points.length > 1)
				min = Math.min(min, entry.data.xMin)
		return isFinite(min) ? min : 0
	}

	function _dataXMax() {
		let max = -Infinity
		for (const entry of root.series)
			if (entry.data && entry.data.points && entry.data.points.length > 1)
				max = Math.max(max, entry.data.xMax)
		return isFinite(max) ? max : 0
	}

	// Identical to LineChart's _seek/_bracket, parameterised on an xs array instead of reading
	// _flat implicitly - the one thing that has to change to serve more than one series.
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

	function _bracket(xs) {
		if (xs.length < 2)
			return { first: 0, last: 0 }

		const first = _seek(xs, xLow)
		let last = _seek(xs, xHigh)
		while (last < xs.length && xs[last] <= xHigh)
			++last

		return { first: first, last: last }
	}

	function _range() {
		if (Trace.enabled) Trace.begin("overlay.range")
		try {
			return _rangeInWindow()
		} finally {
			if (Trace.enabled) Trace.end("overlay.range")
		}
	}

	// The range is the union of every series' points inside the window, and `count` - what
	// decides hasVisible - is the MAX of their in-window point counts, not the sum: a chart
	// with two live layers and one empty one must still draw the two, not read as empty because
	// one layer alone would not.
	function _rangeInWindow() {
		const empty = { count: 0, low: 0, high: 0 }
		if (!hasData)
			return empty

		let count = 0
		let low = Infinity
		let high = -Infinity
		for (let s = 0; s < root.series.length; ++s) {
			const ys = _flat[s].ys
			const w = _windows[s]
			count = Math.max(count, w.last - w.first)
			for (let i = w.first; i < w.last; ++i) {
				low = Math.min(low, ys[i])
				high = Math.max(high, ys[i])
			}
		}
		if (count === 0)
			return empty

		if (!isNaN(fixedLow))
			low = fixedLow
		if (!isNaN(fixedHigh))
			high = fixedHigh

		if (isNaN(fixedLow))
			low = Math.min(low, high - minimumSpan)
		return { count: count, low: low, high: Math.max(high, low + minimumSpan) }
	}

	function _plot(s) {
		if (Trace.enabled) Trace.begin("overlay.plot")
		try {
			return _plotFor(s)
		} finally {
			if (Trace.enabled) Trace.end("overlay.plot")
		}
	}

	function _plotFor(s) {
		if (!hasVisible || plot.width <= 0 || plot.height <= 0)
			return []

		const xs = _flat[s].xs
		const ys = _flat[s].ys
		if (xs.length < 2)
			return []

		const xSpan = Math.max(1, xHigh - xLow)
		const ySpan = Math.max(1e-6, yHigh - yLow)
		const w = _windows[s]
		const from = Math.max(0, w.first - 1)
		const to = Math.min(xs.length - 1, w.last)

		const out = []
		for (let i = from; i <= to; ++i)
			out.push(Qt.point(
				(xs[i] - xLow) / xSpan * plot.width,
				plot.height - (ys[i] - yLow) / ySpan * plot.height))
		return out
	}

	readonly property var _levelGrid: _levels()
	readonly property var _dayGrid: _days()

	function _step(span) {
		const raw = span / 5
		const magnitude = Math.pow(10, Math.floor(Math.log10(raw)))
		const steps = [1, 2, 5, 10]
		for (let i = 0; i < steps.length; ++i)
			if (raw <= steps[i] * magnitude)
				return steps[i] * magnitude
		return 10 * magnitude
	}

	function _levels() {
		const span = yHigh - yLow
		if (!hasVisible || span <= 0)
			return { first: 0, step: 0, count: 0 }

		const step = _step(span)

		let first = Math.ceil(yLow / step) * step
		if (first <= yLow)
			first += step

		return { first: first, step: step, count: Math.max(0, Math.ceil((yHigh - first) / step)) }
	}

	function _days() {
		if (!hasVisible)
			return { first: 0, count: 0 }

		const at = new Date(xLow)
		at.setHours(24, 0, 0, 0)

		const first = at.getTime()
		let count = 0
		while (at.getTime() < xHigh) {
			++count
			at.setDate(at.getDate() + 1)
		}
		return { first: first, count: count }
	}

	function _dayAfter(first, n) {
		const at = new Date(first)
		at.setDate(at.getDate() + n)
		return at.getTime()
	}

	function _time(milliseconds) {
		const hours = (xHigh - xLow) / 3600000
		const format = hours > 96 ? "ddd d MMM" : (hours > 12 ? "ddd HH:mm" : "HH:mm")
		return Qt.formatDateTime(new Date(milliseconds), format)
	}

	Text {
		anchors.centerIn: parent
		visible: !root.hasVisible
		text: "brak danych"
		color: Theme.textDim
		font.pixelSize: Theme.fontBody
	}

	Item {
		anchors { left: parent.left; top: parent.top; bottom: axis.top }
		width: root._gutter
		visible: root.hasVisible

		Text {
			anchors { left: parent.left; top: parent.top }
			text: root.yHigh.toFixed(root.decimals) + root.unit
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { left: parent.left; bottom: parent.bottom }
			text: root.yLow.toFixed(root.decimals) + root.unit
			color: Theme.text
			font.pixelSize: Theme.fontBody
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

		Repeater {
			model: root._levelGrid.count

			Rectangle {
				readonly property real level:
					root._levelGrid.first + index * root._levelGrid.step
				readonly property real span: Math.max(1e-6, root.yHigh - root.yLow)

				y: Math.round(plot.height - (level - root.yLow) / span * plot.height)
				width: plot.width
				height: 1
				color: Theme.grid
			}
		}

		Repeater {
			model: root._dayGrid.count

			Rectangle {
				readonly property real at: root._dayAfter(root._dayGrid.first, index)
				readonly property real span: Math.max(1, root.xHigh - root.xLow)

				x: Math.round((at - root.xLow) / span * plot.width)
				width: 1
				height: plot.height
				color: Theme.grid
			}
		}

		// One PathPolyline per series, a Repeater bound to a count (series.length) and not to
		// the series list itself - each delegate reads its own path from `index`, same
		// discipline the two grids above already use.
		Repeater {
			model: root.series.length

			Shape {
				anchors.fill: parent
				visible: root.hasVisible
				ShapePath {
					strokeColor: root.series[index].stroke
					strokeWidth: 3
					fillColor: "transparent"
					capStyle: ShapePath.RoundCap
					joinStyle: ShapePath.RoundJoin
					PathPolyline { path: root.hasVisible ? root._plot(index) : [] }
				}
			}
		}
	}

	Item {
		id: axis
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: Theme.fontBody + 6
		visible: root.hasVisible

		Text {
			anchors.left: parent.left
			anchors.leftMargin: root._gutter + Theme.gap
			text: root.hasVisible ? root._time(root.xLow) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
		}
		Text {
			anchors.right: parent.right
			text: root.hasVisible ? root._time(root.xHigh) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
		}
	}
}
