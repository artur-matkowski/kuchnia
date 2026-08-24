import QtQuick
import Kuchnia

// A whole screen, and where it stands.
//
// Outside the carousel this is the identity: every screen fills the scene and its elements
// animate themselves in and out, which is what the rest of the scene is built on. In the
// carousel it is the miniature: the screen keeps its full-size layout and is put through one
// Scale and one Translate into its card.
//
// That split is the point. An element that animated itself into a miniature would arrive from
// wherever its own context leaves it - a gauge from the left, a camera zooming at the viewer -
// and four screens would assemble out of loose parts. Moved as frames they arrive as the
// screens they are.
//
// The Scale is about 0,0 and not Item.scale, which is centre-origin: a frame is positioned by
// its own top left corner and Carousel's arithmetic says where that corner goes.
Item {
	id: frame

	// Which card this frame is a miniature in.
	property string card: ""

	// Whether this frame is the one that zooms rather than slides. Normally that is the card
	// the strip stands on; WeatherLayer overrides it, because it lives on two screens and is in
	// flight whenever either of them is the one being opened or left.
	property bool focused: Carousel.focused === frame.card

	// What z is outside the carousel. Inside it, depth follows the distance from the centre of
	// the strip, because the cards overlap at the edges and the centred one has to be on top.
	property real baseZ: 0

	property real shrink: 1
	property real frameX: 0
	property real frameY: 0

	anchors.fill: parent

	z: Nav.current === "carousel" ? Carousel.depth(frame.card) : frame.baseZ

	transform: [
		Scale { origin.x: 0; origin.y: 0; xScale: frame.shrink; yScale: frame.shrink },
		Translate { x: frame.frameX; y: frame.frameY }
	]

	state: Nav.current

	// Which frame the state machine is on, and when. The context assignment applies six of
	// these one after another, and the gaps between the marks are where its cost sits - see
	// docs/diagnostics.md. Guarded because the string is built before the call, whether or not
	// anything is listening.
	onStateChanged: if (Trace.enabled) Trace.mark("frame " + frame.card + " -> " + frame.state)

	// Every id, because a state name a StateGroup cannot find is a state group with nothing
	// applied and a Transition that never matches - a screen that snaps into its card instead
	// of arriving in it.
	states: [
		State { name: "cameras" },
		State { name: "compact-24h" },
		State { name: "compact-72h" },
		State { name: "weather-72h" },
		State { name: "weather-7d" },
		State { name: "settings" },
		State {
			name: "carousel"
			// Bindings, not values: the strip slides while the carousel is on, and every
			// frame's place in it follows Carousel.position as it eases.
			PropertyChanges {
				target: frame
				shrink: Carousel.shrink(frame.card)
				frameX: Carousel.cardX(frame.card)
				frameY: Carousel.cardY(frame.card)
			}
		}
	]

	transitions: [
		// In. The focused frame starts where it is - full size, at the origin - and zooms out
		// into the middle of the strip. Every other frame starts already shrunk and already a
		// screen further out than its card, and slides in from there.
		Transition {
			from: Nav.elsewhere; to: "carousel"
			ParallelAnimation {
				NumberAnimation {
					properties: "shrink"
					from: frame.focused ? 1 : Carousel.shrink(frame.card)
					duration: 560
					easing.type: Easing.InOutCubic
				}
				NumberAnimation {
					properties: "frameX"
					from: frame.focused ? 0 : Carousel.entryX(frame.card)
					duration: 560
					easing.type: Easing.InOutCubic
				}
				NumberAnimation {
					properties: "frameY"
					from: frame.focused ? 0 : Carousel.cardY(frame.card)
					duration: 560
					easing.type: Easing.InOutCubic
				}
			}
		},
		// Out, and the `to` on each animation is what makes it the way in run backwards. The
		// state being left has already reverted these three to the identity, so an unfocused
		// frame animated at them would fly back to full size in full view; it is sent out to
		// where it came in from instead, and the PropertyAction puts it back at the identity
		// once it is off the edge and nobody can see it happen.
		Transition {
			from: "carousel"; to: Nav.elsewhere
			SequentialAnimation {
				ParallelAnimation {
					NumberAnimation {
						properties: "shrink"
						to: frame.focused ? 1 : Carousel.shrink(frame.card)
						duration: 520
						easing.type: Easing.InOutCubic
					}
					NumberAnimation {
						properties: "frameX"
						to: frame.focused ? 0 : Carousel.entryX(frame.card)
						duration: 520
						easing.type: Easing.InOutCubic
					}
					NumberAnimation {
						properties: "frameY"
						to: frame.focused ? 0 : Carousel.cardY(frame.card)
						duration: 520
						easing.type: Easing.InOutCubic
					}
				}
				PropertyAction { target: frame; properties: "shrink,frameX,frameY" }
			}
		}
	]
}
