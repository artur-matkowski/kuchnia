import QtQuick
import QtQuick.Layouts
import QtHmi

// The three readings the weather screen's top row would otherwise have nowhere to put: how
// much cloud there is and how much is falling out of it, both right now. The charts under
// them forecast the same quantities, and a chart's first sample is not the same claim as a
// reading - it is an hourly bucket that may not have started yet.
Card {
	id: root

	title: "Cloud & precipitation"
	status: Weather.status

	RowLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap * 2

		// Three readings, and the unit is in the caption rather than on the number - which is
		// what the wind card next door already does with km/h. Written together the way
		// open-meteo reports them, "0.0 mm · 0.0 cm" is wider than a third of this row at
		// fontReading, and what the elide takes off the end is the snow.
		//
		// No fallback reading. A panel that is not live shows nothing rather than a plausible
		// number - see docs/state.md.
		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				text: Weather.live ? Weather.cloudCover.toFixed(0) : "--"
				color: Weather.live ? Theme.text : Theme.textDim
				font.pixelSize: Theme.fontReading
				font.bold: true
			}

			Text {
				text: "cloud %"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}

		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				text: Weather.live ? Weather.rain.toFixed(1) : "--"
				color: Weather.live ? Theme.cool : Theme.textDim
				font.pixelSize: Theme.fontReading
				font.bold: true
			}

			Text {
				text: "rain mm"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}

		// Centimetres and not millimetres, which is what open-meteo reports for snow and not a
		// slip: two depths in two units.
		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				text: Weather.live ? Weather.snowfall.toFixed(1) : "--"
				color: Weather.live ? Theme.cool : Theme.textDim
				font.pixelSize: Theme.fontReading
				font.bold: true
			}

			Text {
				text: "snow cm"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}
	}
}
