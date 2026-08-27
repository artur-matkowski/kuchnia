pragma Singleton
import QtQuick

// The camera screen's own state: which camera is filling the screen, where the key that put it
// there was pressed, and whether a camera may open its audio sink.
//
// A singleton for the same reason Nav and Carousel are: the six elements of CamerasScreen each
// ask the same questions, and Actions - which is where a key press lands - is not inside that
// screen and has no other way to reach it.
//
// Fullscreen is deliberately NOT a context. See docs/contexts.md.
QtObject {
	id: cctv

	// The camera filling the screen, numbered from 1 as the tiles are labelled. 0 is the grid.
	property int zoom: 0

	// The context a camera key was pressed on, empty when there is nowhere to go back to. Only
	// a context on Nav's ring is remembered: `carousel` would be returned to with its strip
	// standing wherever it was left, and `settings` is not somewhere to send anybody back into.
	property string returnTo: ""

	// The navigation is here rather than in Actions because it is the same decision as the zoom.
	//
	// OFF the CCTV screen a camera key is a way onto it and never a toggle: the zoom left behind
	// is regularly the very camera being asked for, and a toggle would then answer the key by
	// staying where it is.
	function show(number) {
		if (Nav.current !== "cameras") {
			var from = Nav.cycle.indexOf(Nav.current) >= 0 ? Nav.current : ""
			// AFTER goTo, and that order is the whole of it - see docs/contexts.md. Written
			// first, this visit's zoom is what the screen's own teardown throws away.
			Nav.goTo("cameras")
			cctv.returnTo = from
			cctv.zoom = number
			return
		}
		if (cctv.zoom === number)
			cctv.grid()
		else
			cctv.zoom = number
	}

	// Back to all five, and back to where the camera key was pressed - but only from the CCTV
	// screen itself. Somebody who walked off it with a context key has already chosen where they
	// are, and returning them to a screen they left would read as the panel navigating itself.
	//
	// Going back does NOT drop the zoom: the camera has to keep filling the screen through its
	// own exit animation, or the picture collapses into its cell while the screen it is leaving
	// for is already coming in. CamerasScreen drops the zoom - and this - once it has settled
	// OFF, which is also what keeps `returnTo` from outliving the visit it belongs to.
	function grid() {
		if (cctv.returnTo.length > 0 && Nav.current === "cameras") {
			Nav.goTo(cctv.returnTo)
			return
		}
		cctv.zoom = 0
	}

	// Whether the radio wants the one audio sink, written by RadioPanel and read nowhere but
	// the line below. It is what the panel was ASKED for and not what its player is doing: a
	// station that drops mid-song would otherwise let a camera into the room until it
	// reconnected.
	property bool radioPlaying: false

	// The camera whose sink may be open, 0 for none. Only the one filling the screen: two
	// microphones mixed together is a room with two conversations in it, and a camera nobody
	// is looking at is a sound with no picture to explain it.
	readonly property int audible: cctv.radioPlaying ? 0 : cctv.zoom
}
