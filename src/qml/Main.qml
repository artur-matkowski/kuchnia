import QtQuick
import QtQuick.Window

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
		// text input anywhere - so the arrow keys are never swallowed on the way here.
		focus: true

		// Left and right walk the ring; up and down are the chooser. In the carousel the two
		// horizontal keys slide the strip instead of walking the ring, and down is what picks
		// the centred card. There is no cancel: up in the carousel does nothing.
		Keys.onLeftPressed: Nav.current === "carousel" ? Carousel.step(-1) : Nav.previous()
		Keys.onRightPressed: Nav.current === "carousel" ? Carousel.step(1) : Nav.next()
		Keys.onUpPressed: {
			if (Nav.current === "carousel")
				return
			// The strip has to be standing on the card the scene is arriving from before the
			// context changes, or every miniature slides sideways during the zoom out.
			Carousel.open(Nav.current)
			Nav.goTo("carousel")
		}
		Keys.onDownPressed: if (Nav.current === "carousel") Carousel.confirm()

		// The scene's real size, which under eglfs is the connector's and not the 1366x768 the
		// desktop window is pinned to. Every miniature's geometry is cut out of it.
		Binding { target: Carousel; property: "screenWidth"; value: scene.width }
		Binding { target: Carousel; property: "screenHeight"; value: scene.height }

		// Every context is instantiated once and stays instantiated: a transition animates
		// elements of both screens at the same time, so both have to exist at the same time -
		// and in the carousel all four are on screen at once as miniatures.
		CamerasScreen {}
		DetailsScreen { id: details }
		WeatherScreen { id: weather }
		SettingsScreen {}

		// The three weather cards, which belong to both of the screens above and therefore to
		// neither: they migrate between them rather than being drawn twice. Handing them both
		// sets of slots is the one piece of wiring this file does - a card cannot ask a screen
		// it is not inside where its box is.
		WeatherLayer {
			detailsBoxes: details.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}

		// And the second set of the same three, for the one moment both screens are on screen
		// at once - the carousel, where the layer above stands in the compact miniature and
		// these stand in the weather one.
		CarouselWeather {
			detailsBoxes: details.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}
	}
}
