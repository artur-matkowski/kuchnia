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

	// The dot follows the type scale rather than sitting at a size of its own: an indicator that
	// stays put while the text around it grows is an indicator that stops being seen.
	readonly property real _dot: Math.round(Theme.fontLabel * 0.5)

	spacing: Math.round(Theme.fontLabel * 0.25)

	readonly property color tint: health === "live"       ? Theme.live
	                            : health === "connecting" ? Theme.connecting
	                                                      : Theme.failed

	Rectangle {
		width: root._dot
		height: root._dot
		radius: root._dot / 2
		color: root.tint
		anchors.verticalCenter: parent.verticalCenter
	}

	Text {
		text: root.detail.length > 0 ? root.health + " - " + root.detail : root.health
		color: root.tint
		font.pixelSize: Theme.fontLabel
		// What the dot and the spacing already took, and not a number that repeats them: the two
		// drift apart silently, and the badge then prints across its card's own title.
		width: root.maximumWidth < 0 ? implicitWidth
		                             : Math.min(implicitWidth,
		                                        root.maximumWidth - root._dot - root.spacing)
		horizontalAlignment: Text.AlignRight
		elide: Text.ElideRight
		anchors.verticalCenter: parent.verticalCenter
	}
}
