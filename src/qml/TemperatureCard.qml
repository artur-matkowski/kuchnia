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

	// No fallback reading. A panel that is not live shows nothing rather than a plausible
	// number - see docs/state.md.
	Text {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		text: Weather.live ? Weather.temperature.toFixed(1) + "°C" : "--"
		color: Weather.live ? Theme.text : Theme.textDim
		font.pixelSize: Theme.fontHero
		font.bold: true
	}
}
