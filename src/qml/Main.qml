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
		anchors.fill: parent

		// The only focused item in the application. Nothing else takes focus - there is no
		// text input anywhere - so the arrow keys are never swallowed on the way here.
		focus: true
		Keys.onLeftPressed: Nav.previous()
		Keys.onRightPressed: Nav.next()

		// Every context is instantiated once and stays instantiated: a transition animates
		// elements of both screens at the same time, so both have to exist at the same time.
		CamerasScreen {}
		DetailsScreen { id: details }
		WeatherScreen { id: weather }

		// The three weather cards, which belong to both of the screens above and therefore to
		// neither: they migrate between them rather than being drawn twice. Handing them both
		// sets of slots is the one piece of wiring this file does - a card cannot ask a screen
		// it is not inside where its box is.
		WeatherLayer {
			detailsBoxes: details.weatherBoxes
			weatherBoxes: weather.weatherBoxes
		}
	}
}
