import QtQuick

// The wall clock as a standalone tile. A Card frame with no weather status - it ticks
// whether the network is up or not - and the same Clock component used on the cameras
// screen.
Card {
	id: root
	title: "Godzina"

	Clock {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
	}
}