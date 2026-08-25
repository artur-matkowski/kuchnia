import QtQuick
import Kuchnia

// Where everyone sharing a location is, on one map.
//
// One card filling the screen, because the map is the whole point of the context and a grid
// of anything beside it would only take width away from the thing being read from across the
// room. It is off the pair of forecast spans and carries no span id of its own.
Context {
	id: screen

	contextIds: ["map", "carousel"]
	card: "map"

	// Every id that is not this screen. `carousel` is deliberately absent from it and present
	// in contextIds: a screen that treats the chooser as somewhere else animates itself out
	// from under its own miniature.
	readonly property string away: "cameras,compact-24h,compact-72h,weather-72h,weather-7d,settings"

	// Everything inside the margin - identical in all five screens, so a card that moves
	// between two of them lands where the arithmetic already put it.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	SceneElement {
		id: whereabouts
		box: Cells.box(screen.content, [-1], [-1], 0, 0)

		MapPanel { anchors.fill: parent }

		states: [
			State { name: "cameras"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "settings"; PropertyChanges { target: whereabouts; offsetY: 820; opacity: 0 } },
			State { name: "map" },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: "map"
				NumberAnimation {
					properties: "offsetY,opacity"
					duration: 520
					easing.type: Easing.OutCubic
				}
			},
			Transition {
				from: "map"; to: screen.away
				NumberAnimation {
					properties: "offsetY,opacity"
					duration: 340
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}
}
