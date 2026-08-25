import QtQuick
import Kuchnia

// Everything that is not a camera: the weather, the gate, the tank's history and the radio.
// Each panel is its own SceneElement, so the way this screen assembles itself is written
// panel by panel and does not have to mirror the way the cameras leave.
//
// It is two contexts, not one: compact-24h and compact-72h differ in the width of the
// forecast window and in nothing else. Every element here therefore gives both the same pose,
// and the only thing that moves between them is the forecast window itself - the boxes must
// not move by a pixel when the range changes.
//
// The weather column is not built here: this file only says where its three boxes are. What
// draws in them lives in WeatherLayer, above both screens, so that it can carry itself over to
// the weather context instead of fading out of this one and being built again there.
Context {
	id: screen

	contextIds: ["compact-24h", "compact-72h", "carousel"]
	card: "compact"

	// The two ids as one Transition side. The States below still name them one at a time - a
	// State name is a literal - but a pair that treats the two alike says so once.
	readonly property string spans: "compact-24h,compact-72h"

	// Every id that is not this screen. The panels below are off screen in all of them and
	// leave for the weather context exactly as they leave for the cameras.
	readonly property string away: "cameras,weather-72h,weather-7d,settings,map"

	// Everything inside the margin, in two columns. They are divided differently - the left one
	// is a stack of four, the right one is the gate over the radio - which is why they are cut
	// out first and subdivided separately rather than being one grid.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	readonly property rect leftCol:  Cells.box(screen.content, [-1, -1], [-1], 0, 0)
	readonly property rect rightCol: Cells.box(screen.content, [-1, -1], [-1], 1, 0)

	// The left column: the reading, the forecast, the rain chance and the tank. Row 0 is
	// Theme.readingRow because the weather screen opens with the same height - the temperature
	// card crossing between the two screens must move, not resize.
	function leftCell(row) {
		return Cells.box(screen.leftCol, [-1], [Theme.readingRow, -1, -1, -1], 0, row)
	}

	// What the gate needs and no more, at a 1.2 line height. A literal here is a band that stops
	// fitting the moment the type scale moves, and a card does not clip: the bar is simply drawn
	// over the radio below it.
	readonly property int gateRow:
		Math.round(Theme.fontLabel * 1.2      // the card's heading
		         + Theme.fontReading * 1.2    // the gate's state
		         + Theme.fontLabel * 1.2      // the read-only line, when the config turns it on
		         + Theme.fontBody * 2         // the command bar
		         + Theme.gap * 5)

	// The right column: the gate needs only enough for a state and three buttons, and what is
	// left over is the radio's, which is the column that has a station list to show.
	function rightCell(row) {
		return Cells.box(screen.rightCol, [-1], [screen.gateRow, -1], 0, row)
	}

	// The boxes WeatherLayer's three cards are asked to occupy while this context is on. The
	// names are the whole contract and nothing checks them - a misspelt one is a card that
	// never arrives, with no warning anywhere.
	readonly property var weatherBoxes: ({
		temperature: screen.leftCell(0),
		temperatureChart: screen.leftCell(1),
		rainChance: screen.leftCell(2)
	})

	SceneElement {
		id: gate
		box: screen.rightCell(0)

		GatePanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State {
				name: "weather-72h"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State {
				name: "map"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 320 }
					NumberAnimation {
						properties: "offsetY,opacity"
						duration: 500
						easing.type: Easing.OutBack
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
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

	SceneElement {
		id: hotWater
		box: screen.leftCell(3)

		HotWaterPanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State {
				name: "weather-72h"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State {
				name: "map"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 260 }
					NumberAnimation {
						properties: "scale,opacity"
						duration: 480
						easing.type: Easing.OutCubic
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
				NumberAnimation {
					properties: "scale,opacity"
					duration: 300
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: radio
		box: screen.rightCell(1)

		RadioPanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State {
				name: "weather-72h"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State {
				name: "map"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 380 }
					NumberAnimation {
						properties: "offsetY,opacity"
						duration: 500
						easing.type: Easing.OutBack
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
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
