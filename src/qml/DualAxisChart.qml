import QtQuick
import QtQuick.Shapes
import Kuchnia

// Series on up to two independent vertical axes, sharing one window - rain and snow against a
// left mm/cm axis, humidity as spikes against a right percent axis. See OverlayChart.qml for
// the sibling that shares one axis instead; LineChart.qml stays untouched by both.
Item {
	id: root

	// [{ data, stroke, kind: "line"|"spike", axis: "left"|"right" }, ...]. kind defaults "line",
	// axis defaults "left". `data` is a plain object-literal key, unrelated to Item.data.
	property var series: []

	// { fixedLow, fixedHigh, minimumSpan, unit, decimals } - same fields LineChart.qml exposes
	// as top-level properties, nested one level so two axes can each carry their own.
	property var leftAxis: ({ fixedLow: NaN, fixedHigh: NaN, minimumSpan: 1.0, unit: "", decimals: 1 })
	// null means no right axis is in use - a chart with everything on the left is legal.
	property var rightAxis: null

	property point window: Qt.point(0, 0)
	property var bands: []

	readonly property var _left: _normalizeAxis(root.leftAxis)
	readonly property var _right: root.rightAxis !== null ? _normalizeAxis(root.rightAxis) : null

	readonly property bool hasRightAxis:
		root._right !== null && root.series.some(e => _axisOf(e) === "right")

	readonly property real _leftGutter: Theme.chartGutter
	readonly property real _rightGutter: hasRightAxis ? Theme.chartGutter : 0

	readonly property var _flat: _flattenAll()

	readonly property bool hasData: _flat.some(f => f.xs.length > 1)

	readonly property real xLow:
		root.window.y > root.window.x ? root.window.x : (hasData ? _dataXMin() : 0)
	readonly property real xHigh:
		root.window.y > root.window.x ? root.window.y : (hasData ? _dataXMax() : 0)

	// One bracket per series, which both ranges and every line are taken over.
	readonly property var _windows: _flat.map(f => _bracket(f.xs))

	readonly property var leftRange: _rangeFor("left", _left)
	readonly property var rightRange: hasRightAxis ? _rangeFor("right", _right) : { count: 0, low: 0, high: 0 }

	readonly property bool hasLeftVisible: leftRange.count > 1
	readonly property bool hasRightVisible: rightRange.count > 1
	readonly property bool hasVisible: hasLeftVisible || hasRightVisible

	// Only the left axis draws horizontal gridlines - two grids at two unrelated pixel heights
	// read as noise rather than as two axes. The right axis is its own gutter and labels only.
	readonly property real yLow: leftRange.low
	readonly property real yHigh: leftRange.high

	readonly property int _spikeIndex: _firstIndexOfKind("spike")
	readonly property var _spikeRange: _spikeIndex >= 0 ? _rangeForIndex(_spikeIndex) : { count: 0, low: 0, high: 0 }
	// Reals, so a spike reads its scale without depending on a range object rebuilt every frame.
	readonly property real _spikeLow: _spikeRange.low
	readonly property real _spikeSpan: Math.max(1e-6, _spikeRange.high - _spikeRange.low)
	readonly property int _stride: Theme.sampleStride(plot.width * 3600000 / Math.max(1, xHigh - xLow))

	function _kindOf(entry) { return entry.kind !== undefined ? entry.kind : "line" }
	function _axisOf(entry) { return entry.axis !== undefined ? entry.axis : "left" }

	function _firstIndexOfKind(kind) {
		for (let s = 0; s < root.series.length; ++s)
			if (_kindOf(root.series[s]) === kind)
				return s
		return -1
	}

	function _normalizeAxis(config) {
		return {
			fixedLow: (config && config.fixedLow !== undefined) ? config.fixedLow : NaN,
			fixedHigh: (config && config.fixedHigh !== undefined) ? config.fixedHigh : NaN,
			minimumSpan: (config && config.minimumSpan !== undefined) ? config.minimumSpan : 1.0,
			unit: (config && config.unit !== undefined) ? config.unit : "",
			decimals: (config && config.decimals !== undefined) ? config.decimals : 1
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

	function _rangeFor(axisName, config) {
		const empty = { count: 0, low: 0, high: 0 }
		let count = 0
		let low = Infinity
		let high = -Infinity
		for (let s = 0; s < root.series.length; ++s) {
			if (_axisOf(root.series[s]) !== axisName)
				continue
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

		if (!isNaN(config.fixedLow))
			low = config.fixedLow
		if (!isNaN(config.fixedHigh))
			high = config.fixedHigh

		if (isNaN(config.fixedLow))
			low = Math.min(low, high - config.minimumSpan)
		return { count: count, low: low, high: Math.max(high, low + config.minimumSpan) }
	}

	function _rangeForIndex(s) {
		return _axisOf(root.series[s]) === "right" ? rightRange : leftRange
	}

	function _plotFor(s) {
		if (!hasVisible || plot.width <= 0 || plot.height <= 0 || _kindOf(root.series[s]) !== "line")
			return []

		const xs = _flat[s].xs
		const ys = _flat[s].ys
		if (xs.length < 2)
			return []

		const range = _rangeForIndex(s)
		const xSpan = Math.max(1, xHigh - xLow)
		const ySpan = Math.max(1e-6, range.high - range.low)
		const w = _windows[s]
		const from = Math.max(0, w.first - 1)
		const to = Math.min(xs.length - 1, w.last)

		const out = []
		for (let i = from; i <= to; ++i)
			out.push(Qt.point(
				(xs[i] - xLow) / xSpan * plot.width,
				plot.height - (ys[i] - range.low) / ySpan * plot.height))
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
		if (!hasLeftVisible || span <= 0)
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
		width: root._leftGutter
		visible: root.hasLeftVisible

		Text {
			anchors { left: parent.left; top: parent.top }
			text: root.yHigh.toFixed(root._left.decimals) + root._left.unit
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { left: parent.left; bottom: parent.bottom }
			text: root.yLow.toFixed(root._left.decimals) + root._left.unit
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
	}

	Item {
		anchors { right: parent.right; top: parent.top; bottom: axis.top }
		width: root._rightGutter
		visible: root.hasRightAxis && root.hasRightVisible

		Text {
			anchors { right: parent.right; top: parent.top }
			text: root.rightRange.high.toFixed(root._right ? root._right.decimals : 0)
			      + (root._right ? root._right.unit : "")
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { right: parent.right; bottom: parent.bottom }
			text: root.rightRange.low.toFixed(root._right ? root._right.decimals : 0)
			      + (root._right ? root._right.unit : "")
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
	}

	Item {
		id: plot
		anchors {
			left: parent.left; leftMargin: root._leftGutter + Theme.gap
			right: parent.right; rightMargin: root._rightGutter > 0 ? root._rightGutter + Theme.gap : 0
			top: parent.top; bottom: axis.top
		}
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

		// The spike series, counted whole and thinned by `_stride`; declared before the lines so
		// they are drawn over it. See docs/charts.md.
		Repeater {
			model: root.hasVisible && root._spikeIndex >= 0
				? root._flat[root._spikeIndex].xs.length
				: 0

			Rectangle {
				readonly property real at: root._flat[root._spikeIndex].xs[index]
				readonly property real value: root._flat[root._spikeIndex].ys[index]
				readonly property int hour: new Date(at).getHours()

				opacity: hour % root._stride === 0 ? 1 : 0
				visible: opacity > 0
				Behavior on opacity { NumberAnimation { duration: 200 } }

				width: 4
				// Gated on `visible`, so a thinned-out spike stops following the window.
				x: visible
					? Math.round((at - root.xLow) / Math.max(1, root.xHigh - root.xLow) * plot.width - width / 2)
					: 0
				height: Math.max(1, Math.round((value - root._spikeLow) / root._spikeSpan * plot.height))
				y: plot.height - height
				color: root.series[root._spikeIndex].stroke
			}
		}

		Repeater {
			model: root.series.length

			Shape {
				anchors.fill: parent
				visible: root.hasVisible && root._kindOf(root.series[index]) === "line"
				ShapePath {
					strokeColor: root.series[index].stroke
					strokeWidth: 3
					fillColor: "transparent"
					capStyle: ShapePath.RoundCap
					joinStyle: ShapePath.RoundJoin
					PathPolyline { path: root.hasVisible ? root._plotFor(index) : [] }
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
			anchors.leftMargin: root._leftGutter + Theme.gap
			text: root.hasVisible ? root._time(root.xLow) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
		}
		Text {
			anchors.right: parent.right
			anchors.rightMargin: root._rightGutter > 0 ? root._rightGutter + Theme.gap : 0
			text: root.hasVisible ? root._time(root.xHigh) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
		}
	}
}
