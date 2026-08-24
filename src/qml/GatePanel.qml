import QtQuick
import QtQuick.Layouts
import Kuchnia

Card {
	id: root

	title: "Brama"
	status: Gate.status
	statusDetail: Gate.statusDetail

	// The bridge's signal names as words. Gate.state stays the bridge's own string - it is what
	// canOpen/canClose/canStop are decided on - so the Polish lives here and nowhere else. A
	// signal this does not know draws as itself rather than as the nearest guess.
	readonly property var _states: ({
		"GateOpened":       "Otwarta",
		"GateClosed":       "Zamknięta",
		"GateOpening":      "Otwieranie",
		"GateClosing":      "Zamykanie",
		"GateStopped":      "Zatrzymana",
		"GateStuckOpening": "Zacięta przy otwieraniu",
		"GateStuckClosing": "Zacięta przy zamykaniu"
	})

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			Layout.fillWidth: true
			// Empty after the broker is live means the bridge has never published, not that
			// the connection is slow: every gate topic is retained and arrives on subscribe.
			text: Gate.state.length > 0 ? (root._states[Gate.state] || Gate.state)
			    : Gate.live ? "brak sygnału z bramy"
			                : "czekam na brokera"
			color: Gate.state.length > 0 ? Theme.text : Theme.textDim
			font.pixelSize: Gate.state.length > 0 ? Theme.fontReading : Theme.fontBody
			font.bold: Gate.state.length > 0
			elide: Text.ElideRight
		}

		Text {
			Layout.fillWidth: true
			visible: !Gate.controlEnabled
			text: "read only - gate-control is not set"
			color: Theme.textDim
			font.pixelSize: Theme.fontLabel
		}

		// What is left of the card, so the bar sits along its lower edge with the state above.
		// Explicit on a plain Item, where it defaults to false rather than to true.
		Item { Layout.fillHeight: true }

		// The three commands as one bar, as tall as the radio's transport buttons and no taller.
		// Layout.fillHeight here instead would hand it every pixel the state text leaves, which
		// is most of the card. Which sections are available comes from Gate and not from the
		// state name spelled again here - see docs/state.md.
		SegmentedBar {
			Layout.fillWidth: true
			Layout.preferredHeight: Theme.fontBody * 2

			model: [
				{ text: "Otwórz",  enabled: Gate.canOpen },
				{ text: "Stop",    enabled: Gate.canStop },
				{ text: "Zamknij", enabled: Gate.canClose }
			]

			onActivated: function(index) {
				if (index === 0)
					Gate.open()
				else if (index === 1)
					Gate.halt()
				else
					Gate.close()
			}
		}
	}
}
