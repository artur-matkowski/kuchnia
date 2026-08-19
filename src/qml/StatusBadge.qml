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

	spacing: 4

	readonly property color tint: health === "live"       ? Theme.live
	                            : health === "connecting" ? Theme.connecting
	                                                      : Theme.failed

	Rectangle {
		width: 8
		height: 8
		radius: 4
		color: root.tint
		anchors.verticalCenter: parent.verticalCenter
	}

	Text {
		text: root.detail.length > 0 ? root.health + " - " + root.detail : root.health
		color: root.tint
		font.pixelSize: 11
		elide: Text.ElideRight
		anchors.verticalCenter: parent.verticalCenter
	}
}
