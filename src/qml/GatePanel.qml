import QtQuick
import QtQuick.Layouts
import QtHmi

Card {
	id: root

	title: "Gate"
	status: Gate.status
	statusDetail: Gate.statusDetail

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			Layout.fillWidth: true
			// Empty after the broker is live means the bridge has never published, not that
			// the connection is slow: every gate topic is retained and arrives on subscribe.
			text: Gate.state.length > 0 ? Gate.state
			    : Gate.live ? "no signal published yet"
			                : "waiting for the broker"
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

		// The three commands as one bar, filling what is left of the card. Which sections are
		// available comes from Gate and not from the state name spelled again here - see
		// docs/state.md.
		SegmentedBar {
			Layout.fillWidth: true
			Layout.fillHeight: true

			model: [
				{ text: "Open",  enabled: Gate.canOpen },
				{ text: "Stop",  enabled: Gate.canStop },
				{ text: "Close", enabled: Gate.canClose }
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
