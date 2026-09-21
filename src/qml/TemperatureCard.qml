import QtQuick
import QtQuick.Layouts
import Kuchnia

// What it is doing outside, right now. The one card of the six that carries the weather
// client's error text, because it is the one that is on the screen in every weather context.
//
// On the compact screen the card's right half is the wall clock; on the weather screen it
// carries only the reading, because the weather screen has its own time display in the
// navigation bar. The clock is the same component used on the cameras screen.
Card {
	id: root

	title: "Temperatura"
	status: Weather.status
	statusDetail: Weather.statusDetail

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

		// The clock, on the compact screen only. When the card migrates to the weather screen
		// it hides; when it returns it is back. No layout surgery, no separate panel.
		Clock {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			visible: Nav.current === "compact-72h"
		}
	}
}
