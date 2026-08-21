pragma Singleton
import QtQuick

// The forecast window every weather chart is drawn through: where it starts, how wide it is,
// and the animation that widens it.
//
// A singleton for the same reason Nav is one. Six cards on two screens draw against one
// window, and threading a reference to it through both layouts would be plumbing; more to the
// point, a window each card owned a copy of is six copies of one fact, and the three that
// migrate would then have to hand their copy over mid-flight.
//
// This is the only element in the scene whose animation is not written where it is used. It
// has no pose and nothing to stagger against - it is a number - and the six span pairs are
// the same six pairs on both screens.
Item {
	id: span

	// The width of the window. Never bound to Nav.current directly: a binding steps when the
	// key is pressed, and the whole point of the three spans is that the chart compresses.
	property real ms: 24 * 3600 * 1000

	// The window is anchored at now and runs forward, so the first thing on a chart is the
	// next hour and not the small hours of this morning. Date.now() is not a property: bound
	// directly it evaluates once and the window never moves again - the trap Clock.qml
	// documents. Once a minute is finer than a pixel at any of these spans.
	property real now: Date.now()

	readonly property real windowStart: span.now
	readonly property real windowEnd: span.now + span.ms

	// Which span is showing, taken from the context id so it changes on the key press rather
	// than following the range as it eases.
	readonly property string label: Nav.current.indexOf("-") > 0
		? Nav.current.substring(Nav.current.indexOf("-") + 1) : ""

	Timer {
		interval: 60000
		running: true
		repeat: true
		onTriggered: span.now = Date.now()
	}

	state: Nav.current

	// restoreEntryValues is false on all six: leaving for the cameras would otherwise restore
	// the base 24h, and a week-wide chart would snap shut while it is still flying off screen.
	// The cameras context therefore names no value of its own - it keeps whatever was showing.
	states: [
		State { name: "cameras" },
		State { name: "details-24h"; PropertyChanges { target: span; ms: 24 * 3600 * 1000; restoreEntryValues: false } },
		State { name: "details-72h"; PropertyChanges { target: span; ms: 72 * 3600 * 1000; restoreEntryValues: false } },
		State { name: "weather-72h"; PropertyChanges { target: span; ms: 72 * 3600 * 1000; restoreEntryValues: false } },
		State { name: "weather-7d";  PropertyChanges { target: span; ms: 168 * 3600 * 1000; restoreEntryValues: false } }
	]

	// The six ordered span pairs, named on both screens at once: a span change reads the same
	// whichever screen it happens on, and the screen it happens on is not this element's
	// business. A pair whose two sides are the same span - details-24h to weather-24h - is in
	// none of them, because there is nothing to move.
	//
	// Nothing here names a pair with the cameras in it either. The chart is off screen or
	// arriving from off screen, and a window easing open behind an element that is still
	// flying in is an animation nobody sees.
	transitions: [
		Transition {
			from: "details-24h"; to: "details-72h"
			NumberAnimation { properties: "ms"; duration: 560; easing.type: Easing.OutCubic }
		},
		Transition {
			from: "details-72h"; to: "details-24h"
			NumberAnimation { properties: "ms"; duration: 520; easing.type: Easing.InOutCubic }
		},
		Transition {
			from: "weather-72h"; to: "weather-7d"
			NumberAnimation { properties: "ms"; duration: 560; easing.type: Easing.OutCubic }
		},
		Transition {
			from: "weather-7d"; to: "weather-72h"
			NumberAnimation { properties: "ms"; duration: 520; easing.type: Easing.InOutCubic }
		}
	]
}
