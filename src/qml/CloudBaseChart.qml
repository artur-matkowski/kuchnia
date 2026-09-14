import QtQuick
import QtQuick.Shapes
import Kuchnia

// Cloud bases and tops as dots on a height axis, and visibility as a line on a second one -
// ICM's "Podstawa chmur o pokryciu". The window, the bands and the day grid are OverlayChart's;
// what is particular here is in docs/charts.md.
Item {
	id: root

	// [{ data: <ChartSeries>, color }, ...] in km, drawn in this order: the strictest threshold
	// last, so it is the one seen where two coincide.
	property var bases: []
	// ChartSeries in km, drawn beneath the bases. Not `top`: that is Item's anchor line.
	property var tops: null
	property color topColor: Theme.text
	// ChartSeries in metres, open-meteo's unit; the right axis is labelled in km.
	property var visibility: null
	property color visibilityColor: Theme.text
	// ChartSeries of the hours the profile covers; only x is read.
	property var hours: null

	property point window: Qt.point(0, 0)
	property var bands: []

	readonly property real _gutter: Theme.fontBody * 3.2
	readonly property int _dot: 10

	readonly property real _heightTop: 15
	readonly property real _heightMid: 2
	readonly property real _sightTop: 50
	readonly property real _sightMid: 10
	readonly property var _gridKm: [0.5, 1, 2, 5, 10]

	// Once per series change, never per frame - see docs/charts.md.
	readonly property var _baseFlat: bases.map(entry => _flatten(entry.data))
	readonly property var _topFlat: _flatten(tops)
	readonly property var _sightFlat: _flatten(visibility)
	readonly property var _hourFlat: _flatten(hours)

	readonly property bool hasData: _hourFlat.xs.length > 1
	readonly property real _knownUntil: hasData ? _hourFlat.xs[_hourFlat.xs.length - 1] : 0

	readonly property real xLow:
		root.window.y > root.window.x ? root.window.x : (hasData ? _hourFlat.xs[0] : 0)
	readonly property real xHigh:
		root.window.y > root.window.x ? root.window.y : _knownUntil

	readonly property var _hourWindow: _bracket(_hourFlat.xs)
	readonly property var _sightWindow: _bracket(_sightFlat.xs)

	readonly property bool hasVisible: _hourWindow.last - _hourWindow.first > 1
	readonly property bool hasSightVisible:
		hasVisible && _sightWindow.last - _sightWindow.first > 1

	readonly property var _dayGrid: _days()

	function _flatten(data) {
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

	// 0 at the ground, 1 at `top` and exactly 0.5 at `mid`: ln(1 + v/k) / ln(1 + top/k) with
	// k = mid² / (top - 2·mid). A value past `top` stays on the top edge.
	function _curve(value, top, mid) {
		const knee = mid * mid / (top - 2 * mid)
		return Math.min(1, Math.log(1 + Math.max(0, value) / knee) / Math.log(1 + top / knee))
	}

	function _xOf(at) {
		return (at - xLow) / Math.max(1, xHigh - xLow) * plot.width
	}

	function _yOfKm(km) {
		return plot.height * (1 - _curve(km, _heightTop, _heightMid))
	}

	function _sightPath() {
		if (!hasSightVisible || plot.width <= 0 || plot.height <= 0)
			return []

		const xs = _sightFlat.xs
		const ys = _sightFlat.ys
		const from = Math.max(0, _sightWindow.first - 1)
		const to = Math.min(xs.length - 1, _sightWindow.last)

		const out = []
		for (let i = from; i <= to; ++i)
			out.push(Qt.point(_xOf(xs[i]),
			                  plot.height * (1 - _curve(ys[i] / 1000, _sightTop, _sightMid))))
		return out
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

	// Three labels to an axis and none between: the scale bends, so only the ends and the
	// middle can be read off it - see docs/charts.md.
	Item {
		anchors { left: parent.left; top: parent.top; bottom: axis.top }
		width: root._gutter
		visible: root.hasVisible

		Text {
			anchors { left: parent.left; top: parent.top }
			text: root._heightTop + "km"
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { left: parent.left; verticalCenter: parent.verticalCenter }
			text: root._heightMid + "km"
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { left: parent.left; bottom: parent.bottom }
			text: "0km"
			color: Theme.text
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
	}

	Item {
		anchors { right: parent.right; top: parent.top; bottom: axis.top }
		width: root._gutter
		visible: root.hasSightVisible

		Text {
			anchors { right: parent.right; top: parent.top }
			text: root._sightTop + "km"
			color: root.visibilityColor
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { right: parent.right; verticalCenter: parent.verticalCenter }
			text: root._sightMid + "km"
			color: root.visibilityColor
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
		Text {
			anchors { right: parent.right; bottom: parent.bottom }
			text: "0km"
			color: root.visibilityColor
			font.pixelSize: Theme.fontBody
			font.bold: true
		}
	}

	Item {
		id: plot
		anchors {
			left: parent.left; leftMargin: root._gutter + Theme.gap
			right: parent.right; rightMargin: root._gutter + Theme.gap
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
			model: root.hasVisible ? root._gridKm.length : 0

			Rectangle {
				y: Math.round(root._yOfKm(root._gridKm[index]))
				width: plot.width
				height: 1
				color: Theme.grid
			}
		}

		Repeater {
			model: root._dayGrid.count

			Rectangle {
				readonly property real at: root._dayAfter(root._dayGrid.first, index)

				x: Math.round(root._xOf(at))
				width: 1
				height: plot.height
				color: Theme.grid
			}
		}

		// Past the last hour the profile covers, an empty sky is no data rather than no cloud.
		Rectangle {
			readonly property real from: Math.max(0, root._xOf(root._knownUntil))

			visible: root.hasVisible && root._knownUntil < root.xHigh
			x: from
			width: plot.width - from
			height: plot.height
			color: Theme.background
			opacity: 0.6
		}

		// Every dot Repeater counts its whole series, not the window - see docs/charts.md.
		Repeater {
			model: root.hasVisible ? root._topFlat.xs.length : 0

			Rectangle {
				width: root._dot
				height: root._dot
				radius: root._dot / 2
				x: Math.round(root._xOf(root._topFlat.xs[index]) - width / 2)
				y: Math.round(root._yOfKm(root._topFlat.ys[index]) - height / 2)
				color: root.topColor
			}
		}

		Repeater {
			model: root.bases.length

			Item {
				id: threshold
				readonly property int series: index
				anchors.fill: parent

				Repeater {
					model: root.hasVisible ? root._baseFlat[threshold.series].xs.length : 0

					Rectangle {
						width: root._dot
						height: root._dot
						radius: root._dot / 2
						x: Math.round(root._xOf(root._baseFlat[threshold.series].xs[index]) - width / 2)
						y: Math.round(root._yOfKm(root._baseFlat[threshold.series].ys[index]) - height / 2)
						color: root.bases[threshold.series].color
					}
				}
			}
		}

		Shape {
			anchors.fill: parent
			visible: root.hasSightVisible
			ShapePath {
				strokeColor: root.visibilityColor
				strokeWidth: 3
				fillColor: "transparent"
				capStyle: ShapePath.RoundCap
				joinStyle: ShapePath.RoundJoin
				PathPolyline { path: root._sightPath() }
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
			anchors.rightMargin: root._gutter + Theme.gap
			text: root.hasVisible ? root._time(root.xHigh) : ""
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
		}
	}
}
