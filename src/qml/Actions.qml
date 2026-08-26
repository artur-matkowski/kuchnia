pragma Singleton
import QtQuick
import Kuchnia

// What an action does. `KeyBindings` says which key runs which id; this says what the id means,
// and the two are the whole of the input path.
//
// An action whose state belongs to a singleton is performed here. Some does not - what the radio
// is playing belongs to the MediaPlayer in RadioPanel.qml - so an action is also announced on
// `invoked`, and the panel that owns the state answers it there. An action fully performed here
// returns before announcing, which is how `refresh` reaches one panel and not the other. See
// docs/input.md.
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

			// The sound server's, and not this application's: there is no level held here to
			// move - see docs/volume.md.
			case "volume-up":
				Volume.up()
				break
			case "volume-down":
				Volume.down()
				break

			case "radio-play-stop":
			case "radio-next":
			case "radio-previous":
				break

			// Two screens own this key and the context says which, decided here so it is decided
			// once - MapPanel answers `invoked` and would otherwise need the same test with its sign
			// flipped. The compact screen's half is the Radio singleton's and is done here; the map's
			// is not, so only that one is announced. Anywhere else - the cameras, the weather, the
			// chooser, settings - the key does nothing and announces nothing: refreshing a screen
			// nobody is looking at is a poll with no visible result.
			case "refresh":
				if (Carousel.cardOf(Nav.current) === "compact") {
					Radio.reload()
					return
				}
				if (Nav.current !== "map")
					return
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
