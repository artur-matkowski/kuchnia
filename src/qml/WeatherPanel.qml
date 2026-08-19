import QtQuick
import QtQuick.Layouts
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

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		// The temperature outside is the one number on this panel read from across the room,
		// so it is on its own scale and everything beside it is a detail.
		RowLayout {
			Layout.fillWidth: true
			// Explicit, because it defaults to true for a nested layout: left alone this row
			// takes the whole column and both charts are laid out one pixel high.
			Layout.fillHeight: false
			spacing: Theme.gap

			Text {
				text: Weather.live ? Weather.temperature.toFixed(1) + "°C" : "--"
				color: Weather.live ? Theme.text : Theme.textDim
				font.pixelSize: Theme.fontHero
				font.bold: true
			}

			Text {
				Layout.fillWidth: true
				Layout.alignment: Qt.AlignBottom
				visible: Weather.live
				text: Weather.humidity.toFixed(0) + "%   wmo " + Weather.weatherCode
				color: Theme.textDim
				font.pixelSize: Theme.fontBody
				elide: Text.ElideRight
			}
		}

		LineChart {
			Layout.fillWidth: true
			Layout.fillHeight: true
			series: Weather.temperatureForecast
			bands: Weather.daylight
			windowStart: root.now
			windowEnd: root.now + root.spanMs
			stroke: Theme.cool
			unit: "°"
			decimals: 0
			minimumSpan: 5
		}

		// Pinned to the whole scale. A probability chart that rescales itself puts 40% at the
		// top of the frame, which reads as a downpour from any distance at which the axis
		// label cannot be read.
		LineChart {
			Layout.fillWidth: true
			Layout.fillHeight: true
			series: Weather.precipitationForecast
			bands: Weather.daylight
			windowStart: root.now
			windowEnd: root.now + root.spanMs
			stroke: Theme.accent
			unit: "%"
			decimals: 0
			fixedLow: 0
			fixedHigh: 100
		}
	}
}
