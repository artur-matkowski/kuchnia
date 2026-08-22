import QtQuick
import QtQuick.Layouts
import QtHmi

// The two readings the weather screen's top row would otherwise have nowhere to put: how much
// cloud there is and how much is falling out of it, both right now. The charts under them
// forecast the same two quantities, and a chart's first sample is not the same claim as a
// reading - it is an hourly bucket that may not have started yet.
Card {
	id: root

	title: "Now"
	status: Weather.status

	RowLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap * 2

		// No fallback reading. A panel that is not live shows nothing rather than a plausible
		// number - see docs/state.md.
		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				text: Weather.live ? Weather.cloudCover.toFixed(0) + "%" : "--"
				color: Weather.live ? Theme.text : Theme.textDim
				font.pixelSize: Theme.fontReading
				font.bold: true
			}

			Text {
				text: "cloud"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}

		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			// Millimetres of rain and centimetres of snow, which is what open-meteo reports and
			// not a slip: they are two units because they are two depths.
			Text {
				text: Weather.live
					? Weather.rain.toFixed(1) + " mm · " + Weather.snowfall.toFixed(1) + " cm"
					: "--"
				color: Weather.live ? Theme.cool : Theme.textDim
				font.pixelSize: Theme.fontReading
				font.bold: true
				elide: Text.ElideRight
				width: parent.width
			}

			Text {
				text: "rain · snow"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}
	}
}
