import QtQuick

// The one rendering of "connecting", "live" or "failed", so every panel says it the same way.
//
// It is never hidden. A panel whose service is down has to look different from one that is
// simply quiet, and an indicator that disappears when it matters most does the opposite.
//
// The property is health and not state: every Item already has a state, and shadowing it
// with a string of our own is accepted silently and then fights QML's own state machine.
Row {
	id: root

	// The string a Panel-backed singleton exposes: Gate.status, HotWater.status, Weather.status.
	property string health: "connecting"
	property string detail: ""

	// What the badge may not grow past, negative meaning "as wide as it likes". The text
	// elides, and elide needs a width: in a narrow card an unbounded detail prints straight
	// across the card's own title, which is the one line that says which panel it is.
	property real maximumWidth: -1

	spacing: 4

	readonly property color tint: health === "live"       ? Theme.live
	                            : health === "connecting" ? Theme.connecting
	                                                      : Theme.failed

	Rectangle {
		width: 10
		height: 10
		radius: 5
		color: root.tint
		anchors.verticalCenter: parent.verticalCenter
	}

	Text {
		text: root.detail.length > 0 ? root.health + " - " + root.detail : root.health
		color: root.tint
		font.pixelSize: Theme.fontLabel
		width: root.maximumWidth < 0 ? implicitWidth
		                             : Math.min(implicitWidth, root.maximumWidth - 14)
		horizontalAlignment: Text.AlignRight
		elide: Text.ElideRight
		anchors.verticalCenter: parent.verticalCenter
	}
}
