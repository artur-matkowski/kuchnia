import QtQuick
import QtQuick.Layouts
import Kuchnia

// What it is doing outside, right now. The one card of the six that carries the weather
// client's error text, because it is the one that is on the screen in every weather context.
Card {
	id: root

	title: "Temperatura"
	status: Weather.status
	statusDetail: Weather.statusDetail

	// The WMO code as words. The number is meaningless from three metres and meaningless from
	// one; the codes are grouped rather than enumerated, because the difference between a
	// slight and a moderate drizzle is not readable from a sofa either.
	function _sky(code) {
		if (code === 0) return "bezchmurnie"
		if (code <= 2) return "małe zachmurzenie"
		if (code === 3) return "pochmurno"
		if (code <= 48) return "mgła"
		if (code <= 57) return "mżawka"
		if (code <= 67) return "deszcz"
		if (code <= 77) return "śnieg"
		if (code <= 82) return "przelotny deszcz"
		if (code <= 86) return "przelotny śnieg"
		return "burza"
	}

	RowLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap * 2

		// No fallback reading. A panel that is not live shows nothing rather than a plausible
		// number - see docs/state.md.
		Text {
			text: Weather.live ? Weather.temperature.toFixed(1) + "°C" : "--"
			color: Weather.live ? Theme.text : Theme.textDim
			font.pixelSize: Theme.fontHero
			font.bold: true
		}

		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				visible: Weather.live
				text: root._sky(Weather.weatherCode)
				color: Theme.text
				font.pixelSize: Theme.fontBody
				elide: Text.ElideRight
				width: parent.width
			}

			Text {
				visible: Weather.live
				text: Weather.humidity.toFixed(0) + "% wilgotności"
				color: Theme.textDim
				font.pixelSize: Theme.fontBody
			}
		}
	}
}
