import QtQuick

// One screen. Fills the scene and overlaps its siblings; which one is seen is decided by the
// elements inside it, not by this.
Item {
	id: context

	property string contextId: ""

	readonly property bool on: Nav.current === contextId

	// What video is gated on, and it is deliberately not `on`: a stream torn down the instant
	// its context goes OFF goes black during its own exit animation, which is the one moment
	// it is still being looked at. It survives until the machine settles.
	readonly property bool live: on || Nav.transitioning

	anchors.fill: parent

	// The incoming context draws over the outgoing one.
	z: on ? 1 : 0
}
