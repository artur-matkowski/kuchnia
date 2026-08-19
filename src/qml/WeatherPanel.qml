import QtQuick
import QtHmi

Card {
	id: root

	// The width of the forecast window, driven by the context machine in DetailsScreen.qml.
	// The panel only reads it: what animates it lives with the states that name the contexts.
	property real spanMs: 24 * 3600 * 1000

	// Which span is showing, taken from the context id, so it changes on the key press rather
	// than following the range as it eases.
	property string spanLabel: ""

	// The window is anchored at now and runs forward, so the first thing on the chart is the
	// next hour and not the small hours of this morning. Date() is not a property: bound
	// directly it evaluates once and the window never moves again - the same trap Clock.qml
	// documents. Once a minute is finer than a pixel at any of these spans.
	property real now: Date.now()

	Timer {
		interval: 60000
		running: true
		repeat: true
		onTriggered: root.now = Date.now()
	}

	title: root.spanLabel ? "Weather · " + root.spanLabel : "Weather"
	status: Weather.status
	statusDetail: Weather.statusDetail

	Column {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			id: reading
			text: Weather.live
			      ? Weather.temperature.toFixed(1) + "°C   " + Weather.humidity.toFixed(0) + "%   wmo " + Weather.weatherCode
			      : "--"
			color: Weather.live ? Theme.text : Theme.textDim
			font.pixelSize: 20
			font.bold: true
		}

		LineChart {
			width: parent.width
			height: (parent.height - parent.spacing * 2 - reading.height) / 2
			series: Weather.temperatureForecast
			bands: Weather.daylight
			windowStart: root.now
			windowEnd: root.now + root.spanMs
			stroke: Theme.cool
			unit: "°"
			minimumSpan: 5
		}

		LineChart {
			width: parent.width
			height: (parent.height - parent.spacing * 2 - reading.height) / 2
			series: Weather.precipitationForecast
			bands: Weather.daylight
			windowStart: root.now
			windowEnd: root.now + root.spanMs
			stroke: Theme.accent
			unit: "%"
			decimals: 0
			minimumSpan: 10
		}
	}
}
