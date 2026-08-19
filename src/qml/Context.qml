import QtQuick

// One screen. Fills the scene and overlaps its siblings; which one is seen is decided by the
// elements inside it, not by this. In the carousel it is a miniature of itself, which is
// CardFrame's business and not this file's.
CardFrame {
	id: context

	// Every id this screen answers to. A list and not one id because the details screen is
	// three contexts - one per forecast span - showing the same boxes in the same places, and
	// because every screen also answers to `carousel`, where all four are on at once.
	property var contextIds: []

	readonly property bool on: contextIds.indexOf(Nav.current) >= 0

	// What video is gated on, and it is deliberately not `on`: a stream torn down the instant
	// its context goes OFF goes black during its own exit animation, which is the one moment
	// it is still being looked at. It survives until the machine settles.
	//
	// A transition this screen takes no part in - a span change on the other screen - must not
	// count, or an off-screen camera is reconnected every time the span moves. `carousel` is in
	// every screen's contextIds, which is what keeps the cameras connected while the chooser is
	// up: the CCTV miniature is moving pictures, and coming back to it costs no reconnect.
	readonly property bool live: on || (Nav.transitioning && contextIds.indexOf(Nav.leaving) >= 0)

	// The incoming context draws over the outgoing one. In the carousel the depth is the
	// strip's, not this.
	baseZ: on ? 1 : 0
}
