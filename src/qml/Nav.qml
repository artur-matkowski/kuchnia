pragma Singleton
import QtQuick

// The context machine. Exactly one context is ON; everything else is OFF, and nothing draws
// a tab bar for it - the only evidence a context exists is what it puts on the screen.
//
// A singleton rather than an object passed down the tree: every animated element reads
// `Nav.current` as its own `state`, and threading a reference through four levels of layout
// to say that would be plumbing, not design.
QtObject {
	id: nav

	// The ids. Each one is written in three places - here, as a Context's `contextId`, and as
	// a State name on every element that animates - and nothing checks that they agree. An id
	// that is misspelled in the third place is not an error: the element simply keeps its base
	// pose and is never animated.
	readonly property var contexts: ["cameras", "details"]

	property string current: contexts[0]

	// How long the machine considers itself in flight. It gates nothing visual - each element
	// owns its own duration - only the point at which an OFF context may tear its video down.
	// It MUST be at least the longest transition in the scene: shorter, and a camera is
	// disconnected part-way through its own exit animation, which reads as a stream that died
	// exactly when you looked away from it.
	property int settleMs: 900

	readonly property bool transitioning: settle.running

	property Timer settle: Timer { interval: nav.settleMs; repeat: false }

	// The any-to-any entry point. next()/previous() are the arrow keys; direct jumps use this.
	function goTo(id) {
		if (nav.contexts.indexOf(id) < 0) {
			console.warn("[nav] no such context: " + id)
			return
		}
		if (id === nav.current)
			return
		// BEFORE the assignment, and that order is the whole of it. `current` is what makes a
		// Context stop being `on`, and `live` is `on || transitioning` - assign first and
		// there is one evaluation pass in which neither holds, so every camera tears its
		// session down and the screen animates out five black tiles.
		//
		// Restarting mid-flight is otherwise deliberate: a state change while a transition is
		// running retargets every animation from wherever it currently is, so a key pressed
		// twice never snaps and never queues.
		settle.restart()
		nav.current = id
	}

	function next() {
		var i = nav.contexts.indexOf(nav.current)
		nav.goTo(nav.contexts[(i + 1) % nav.contexts.length])
	}

	function previous() {
		var i = nav.contexts.indexOf(nav.current)
		nav.goTo(nav.contexts[(i + nav.contexts.length - 1) % nav.contexts.length])
	}
}
