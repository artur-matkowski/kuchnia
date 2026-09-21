import QtQuick
import QtQuick.Window
import Kuchnia

// The shell. It owns the geometry and the keys, and nothing else: what is on the screen is
// decided by the contexts below it and by Nav.
Window {
	id: root

	// Set from C++ before this object is completed - see src/main.cpp. The default is what a
	// scene loaded any other way gets, and the board is the case that matters.
	property bool fullscreen: true

	// The board's panel, which is what the type scale in Theme is measured in - so a window on a
	// desktop is the board 1:1 and worth judging a screenshot from. The board itself still runs
	// fullscreen on whatever the panel reports, and Carousel is bound to that real size below
	// because it is the one thing that has to cut geometry out of it.
	readonly property int panelWidth: 1920
	readonly property int panelHeight: 1080

	width: panelWidth
	height: panelHeight

	// Shown through `visibility` alone - Windowed shows it just as `visible` would, and setting
	// both leaves two writers on one piece of state. The size must stay unpinned: a minimum
	// equal to a maximum is a window the compositor cannot resize to the screen, and the
	// fullscreen request below is then accepted and does nothing.
	visibility: fullscreen ? Window.FullScreen : Window.Windowed
	color: Theme.background
	title: "kuchnia"

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

			// Everything a key press does is done before this returns, so this span is the
			// whole of the work the GUI thread cannot be interrupted during. try/finally and
			// not a pair around the body: every branch below returns out of the middle of it.
			Trace.begin("input.key")
			try {
				event.accepted = true

				// An armed row takes every key there is, or a binding could only ever be made
				// out of keys that already do nothing.
				if (KeyBindings.capturing.length > 0) {
					KeyBindings.apply(event.key)
					return
				}

				// The settings screen's own two keys, and the only hardwired ones left. They
				// are not actions and cannot be bound: a vertical list wants vertical keys, and
				// a screen whose rows cannot be reached is a screen that cannot be repaired.
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
				Trace.mark("key " + event.key + " is " + (action.length > 0 ? action : "unbound"))

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
			} finally {
				Trace.end("input.key")
			}
		}

		// The scene's real size, which fullscreen is the panel's and not the 1366x768 above.
		// Every miniature's geometry is cut out of it.
		Binding { target: Carousel; property: "screenWidth"; value: scene.width }
		Binding { target: Carousel; property: "screenHeight"; value: scene.height }

		// Every context is instantiated once and stays instantiated: a transition animates
		// elements of both screens at the same time, so both have to exist at the same time -
		// and in the carousel all five are on screen at once as miniatures.
		CamerasScreen {}
		CompactScreen { id: compact }
		WeatherScreen { id: weather }
		MapScreen {}
		SettingsScreen { id: settings }

		// The three weather cards and the clock, which belong to both of the screens above and
		// therefore to neither: they migrate between them rather than being drawn twice.
		// Handing them both sets of slots is the one piece of wiring this file does - a card
		// cannot ask a screen it is not inside where its box is.
		WeatherLayer {
			compactBoxes: compact.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}

		// And the second set of the same four, for the one moment both screens are on screen
		// at once - the carousel, where the layer above stands in the compact miniature and
		// these stand in the weather one.
		CarouselWeather {
			compactBoxes: compact.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}
	}
}
