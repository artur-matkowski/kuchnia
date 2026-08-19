import QtQuick

// Everything that is not a camera: the weather, the gate, the tank's history and the radio.
// Each panel is its own SceneElement, so the way this screen assembles itself is written
// panel by panel and does not have to mirror the way the cameras leave.
//
// It is three contexts, not one: details-24h, details-72h and details-7d differ in the width
// of the forecast window and in nothing else. Every element here therefore gives all three
// the same pose, and the only thing that moves between them is the forecast window itself -
// the boxes must not move by a pixel when the range changes.
//
// The weather quadrant is not built here: this file only says where its three boxes are. What
// draws in them lives in WeatherLayer, above both screens, so that it can carry itself over to
// the weather context instead of fading out of this one and being built again there.
Context {
	id: screen

	contextIds: ["details-24h", "details-72h", "details-7d"]

	// The three ids as one Transition side. The States below still name them one at a time -
	// a State name is a literal - but a pair that treats the three alike says so once.
	readonly property string spans: "details-24h,details-72h,details-7d"

	// Every id that is not this screen. The panels below are off screen in all four and leave
	// for the weather context exactly as they leave for the cameras.
	readonly property string away: "cameras,weather-24h,weather-72h,weather-7d"

	// Everything inside the margin, divided in four.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	function cell(column, row) {
		return Cells.box(screen.content, [-1, -1], [-1, -1], column, row)
	}

	// The boxes WeatherLayer's three cards are asked to occupy while this context is on: the
	// top left quadrant, divided the same way the weather screen divides its left column, so
	// the migration is a column growing rather than three cards finding new proportions. The
	// names are the whole contract and nothing checks them - a misspelt one is a card that
	// never arrives, with no warning anywhere.
	readonly property var weatherBoxes: ({
		temperature: Cells.box(screen.cell(0, 0), [-1], [Theme.readingRow, -1, -1], 0, 0),
		temperatureChart: Cells.box(screen.cell(0, 0), [-1], [Theme.readingRow, -1, -1], 0, 1),
		rainChance: Cells.box(screen.cell(0, 0), [-1], [Theme.readingRow, -1, -1], 0, 2)
	})

	SceneElement {
		id: gate
		box: screen.cell(1, 0)

		GatePanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
			}
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
			}
		]
	}

	SceneElement {
		id: hotWater
		box: screen.cell(0, 1)

		HotWaterPanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
			}
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
			}
		]
	}

	SceneElement {
		id: radio
		box: screen.cell(1, 1)

		RadioPanel { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
			}
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
			}
		]
	}
}
