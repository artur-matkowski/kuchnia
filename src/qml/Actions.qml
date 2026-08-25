pragma Singleton
import QtQuick
import Kuchnia

// What an action does. `KeyBindings` says which key runs which id; this says what the id means,
// and the two are the whole of the input path.
//
// An action whose state belongs to a singleton is performed here. One does not - what the radio
// is playing belongs to the MediaPlayer in RadioPanel.qml - so every action is also announced
// on `invoked`, and that panel answers the three that are its own. See docs/input.md.
QtObject {
	id: actions

	signal invoked(string id)

	function run(id) {
		// The action is the unit: everything one key press sets in motion happens inside
		// this call, `invoked` and the panels that answer it included. try/finally because
		// an id nothing handles returns out of the middle of the switch.
		Trace.begin("action." + id)
		try {
			switch (id) {
			case "context-previous":
				Nav.current === "carousel" ? Carousel.step(-1) : Nav.previous()
				break
			case "context-next":
				Nav.current === "carousel" ? Carousel.step(1) : Nav.next()
				break
			case "menu":
				// The strip has to be standing on the card the scene is arriving from before the
				// context changes, or every miniature slides sideways during the zoom out. There is
				// no way back out of the chooser but through a card, so this does nothing inside it.
				if (Nav.current !== "carousel") {
					Carousel.open(Nav.current)
					Nav.goTo("carousel")
				}
				break
			case "confirm":
				if (Nav.current === "carousel")
					Carousel.confirm()
				break

			// Guarded by the same properties the control bar's sections are, so a bound key cannot
			// send a command the panel would not offer - see docs/state.md.
			case "gate-open":
				if (Gate.canOpen)
					Gate.open()
				break
			case "gate-stop":
				if (Gate.canStop)
					Gate.halt()
				break
			case "gate-close":
				if (Gate.canClose)
					Gate.close()
				break

			// The camera keys reach the CCTV screen from anywhere, as the gate keys reach the gate,
			// and the grid key goes back the way they came. Both the zoom and that journey belong to
			// Cctv - this only names which camera.
			case "camera-1":
			case "camera-2":
			case "camera-3":
			case "camera-4":
			case "camera-5":
				Cctv.show(parseInt(id.substring(7)))
				break
			case "camera-grid":
				Cctv.grid()
				break

			case "radio-play-stop":
			case "radio-next":
			case "radio-previous":
			// MapPanel's, for the same reason: the tile cache belongs to its Map, not here.
			case "map-refresh":
				break

			default:
				console.warn("[actions] no such action: " + id)
				return
			}

			actions.invoked(id)
		} finally {
			Trace.end("action." + id)
		}
	}
}
