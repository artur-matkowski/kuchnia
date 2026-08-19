import QtQuick
import QtHmi

Card {
	id: root

	title: "Gate"
	status: Gate.status
	statusDetail: Gate.statusDetail

	Column {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			// Empty after the broker is live means the bridge has never published, not that
			// the connection is slow: every gate topic is retained and arrives on subscribe.
			text: Gate.state.length > 0 ? Gate.state
			    : Gate.live ? "no signal published yet"
			                : "waiting for the broker"
			color: Gate.state.length > 0 ? Theme.text : Theme.textDim
			font.pixelSize: 20
			font.bold: Gate.state.length > 0
		}

		Text {
			visible: !Gate.controlEnabled
			text: "read only - gate-control is not set"
			color: Theme.textDim
			font.pixelSize: 11
		}

		Row {
			spacing: Theme.gap

			Button {
				text: "Open"
				enabled: Gate.controlEnabled
				onClicked: Gate.open()
			}
			Button {
				text: "Stop"
				enabled: Gate.controlEnabled
				onClicked: Gate.halt()
			}
			Button {
				text: "Close"
				enabled: Gate.controlEnabled
				onClicked: Gate.close()
			}
		}
	}
}
