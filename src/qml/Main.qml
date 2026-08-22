import QtQuick
import QtQuick.Window
import QtHmi

// The shell. It owns the geometry and the keys, and nothing else: what is on the screen is
// decided by the contexts below it and by Nav.
Window {
	id: root

	// The panel this scene is composed against, 1:1. Under eglfs the size is ignored and the
	// window takes the whole connector; on a desktop it is pinned rather than merely
	// suggested, so what is being looked at here is what the board will show.
	readonly property int panelWidth: 1366
	readonly property int panelHeight: 768

	width: panelWidth
	height: panelHeight
	minimumWidth: panelWidth
	maximumWidth: panelWidth
	minimumHeight: panelHeight
	maximumHeight: panelHeight

	visible: true
	color: Theme.background
	title: "qt-qml-hmi"

	Item {
		id: scene
		anchors.fill: parent

		// The only focused item in the application. Nothing else takes focus - there is no
		// text input anywhere - so a key press is never swallowed on the way here.
		focus: true

		// Every key press in the application arrives here and leaves as an action. What each
		// action does is Actions.qml's; which key runs it is KeyBindings'. See docs/input.md.
		Keys.onPressed: function(event) {
			// A held key is one press. Auto-repeat on a gate command is a publish per repeat.
			if (event.isAutoRepeat)
				return

			event.accepted = true

			// An armed row takes every key there is, or a binding could only ever be made out
			// of keys that already do nothing.
			if (KeyBindings.capturing.length > 0) {
				KeyBindings.apply(event.key)
				return
			}

			// The settings screen's own two keys, and the only hardwired ones left. They are
			// not actions and cannot be bound: a vertical list wants vertical keys, and a
			// screen whose rows cannot be reached is a screen that cannot be repaired.
			if (Nav.current === "settings") {
				if (event.key === Qt.Key_Up) {
					settings.moveSelection(-1)
					return
				}
				if (event.key === Qt.Key_Down) {
					settings.moveSelection(1)
					return
				}
			}

			const action = KeyBindings.actionFor(event.key)

			// Confirm is what arms a row, so on that screen it never reaches the carousel.
			if (action === "confirm" && Nav.current === "settings") {
				settings.arm()
				return
			}

			if (action.length > 0) {
				Actions.run(action)
				return
			}

			event.accepted = false
		}

		// The scene's real size, which under eglfs is the connector's and not the 1366x768 the
		// desktop window is pinned to. Every miniature's geometry is cut out of it.
		Binding { target: Carousel; property: "screenWidth"; value: scene.width }
		Binding { target: Carousel; property: "screenHeight"; value: scene.height }

		// Every context is instantiated once and stays instantiated: a transition animates
		// elements of both screens at the same time, so both have to exist at the same time -
		// and in the carousel all four are on screen at once as miniatures.
		CamerasScreen {}
		CompactScreen { id: compact }
		WeatherScreen { id: weather }
		SettingsScreen { id: settings }

		// The three weather cards, which belong to both of the screens above and therefore to
		// neither: they migrate between them rather than being drawn twice. Handing them both
		// sets of slots is the one piece of wiring this file does - a card cannot ask a screen
		// it is not inside where its box is.
		WeatherLayer {
			compactBoxes: compact.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}

		// And the second set of the same three, for the one moment both screens are on screen
		// at once - the carousel, where the layer above stands in the compact miniature and
		// these stand in the weather one.
		CarouselWeather {
			compactBoxes: compact.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}
	}
}
