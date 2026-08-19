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

	// The ids the arrow keys walk, in the order they walk them. Each one is written in three
	// places - here, as one of a Context's `contextIds`, and as a State name on every element
	// that animates - and nothing checks that they agree. An id that is misspelled in the
	// third place is not an error: the element simply keeps its base pose and is never
	// animated.
	//
	// Two of the three screens are three ids each - one screen seen over three forecast spans.
	// The three differ in nothing but the width of the forecast window, which is why every
	// element outside that window gives all three the same pose: crossing between them must
	// not move a single box.
	//
	// The weather ids come after the details ids for a reason: the step between the two
	// screens is the one that carries three cards across rather than fading them, and it reads
	// as a step only if it is a step.
	readonly property var cycle: ["cameras", "details-24h", "details-72h", "details-7d",
	                              "weather-24h", "weather-72h", "weather-7d"]

	// Every id `goTo` accepts. `settings` and `carousel` are off the ring on purpose: the
	// carousel is the only way into settings and the only way out of it, and the carousel
	// itself is reached with up.
	readonly property var contexts: nav.cycle.concat(["carousel", "settings"])

	// Every id that is not the carousel, as one Transition side. Every element in the scene
	// names it on the far side of its two carousel pairs, so the list of screens is written
	// once rather than eighteen times.
	readonly property string elsewhere: nav.cycle.join(",") + ",settings"

	property string current: nav.cycle[0]

	// The context being left, for as long as the machine is in flight. `Context.live` needs it:
	// with three details contexts a span change restarts the settle timer, and a `live` that
	// only asked "is anything in flight?" would bring the cameras' streams up for the length of
	// an animation they take no part in.
	property string leaving: nav.cycle[0]

	// The forecast span last asked for, and it is one fact for both screens that carry a
	// forecast. Leaving the details screen at 7d and picking the weather card out of the
	// carousel arrives at `weather-7d`: the miniature that was being looked at is the screen
	// that opens.
	property string lastSpan: "24h"

	// How long the machine considers itself in flight. It gates nothing visual - each element
	// owns its own duration - only the point at which an OFF context may tear its video down.
	// It MUST be at least the longest transition in the scene: shorter, and a camera is
	// disconnected part-way through its own exit animation, which reads as a stream that died
	// exactly when you looked away from it.
	property int settleMs: 900

	readonly property bool transitioning: settle.running

	property Timer settle: Timer { interval: nav.settleMs; repeat: false }

	// The any-to-any entry point. next()/previous() are the arrow keys; the carousel and every
	// direct jump use this.
	function goTo(id) {
		if (nav.contexts.indexOf(id) < 0) {
			console.warn("[nav] no such context: " + id)
			return
		}
		if (id === nav.current)
			return
		if (id.indexOf("-") > 0)
			nav.lastSpan = id.substring(id.indexOf("-") + 1)
		// BEFORE the assignment, and that order is the whole of it. `current` is what makes a
		// Context stop being `on`, and `live` is `on || in a transition it is part of` - assign
		// first and there is one evaluation pass in which neither holds, so every camera tears
		// its session down and the screen animates out five black tiles.
		//
		// Restarting mid-flight is otherwise deliberate: a state change while a transition is
		// running retargets every animation from wherever it currently is, so a key pressed
		// twice never snaps and never queues.
		nav.leaving = nav.current
		settle.restart()
		nav.current = id
	}

	// The two arrow keys. A context off the ring - settings, and the carousel itself - is not
	// in `cycle`, so indexOf answers -1 and the key does nothing rather than jumping somewhere
	// arbitrary.
	function next() {
		var i = nav.cycle.indexOf(nav.current)
		if (i >= 0)
			nav.goTo(nav.cycle[(i + 1) % nav.cycle.length])
	}

	function previous() {
		var i = nav.cycle.indexOf(nav.current)
		if (i >= 0)
			nav.goTo(nav.cycle[(i + nav.cycle.length - 1) % nav.cycle.length])
	}
}
