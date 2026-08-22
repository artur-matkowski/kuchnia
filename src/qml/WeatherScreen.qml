import QtQuick
import QtHmi

// The weather on its own, over two forecast spans like the compact screen.
//
// One rule decides what goes where: the top row is what the weather is doing NOW, and the
// four rows under it are what it is going to do. The three cards in WeatherLayer fill two of
// those slots and are not built here - they arrive from the compact screen carrying the data
// they were already showing.
Context {
	id: screen

	contextIds: ["weather-72h", "weather-7d", "carousel"]
	card: "weather"

	// Every id that is not this screen. The cards this file owns are off screen in all of them
	// and travel the same way in and out of each.
	readonly property string away: "cameras,compact-24h,compact-72h,settings"
	readonly property string spans: "weather-72h,weather-7d"

	// Everything inside the margin.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	// Five rows, full width: the readings across the top and one forecast each below. Row 0 is
	// Theme.readingRow because the compact screen opens its own column with the same height -
	// a card crossing between the two must move, not resize.
	function cell(row) {
		return Cells.box(screen.content, [-1],
		                 [Theme.readingRow, -1, -1, -1, -1], 0, row)
	}

	// Row 0, divided. A cell handed back in as the bounds of a finer grid, which is what Cells
	// is built to allow: the three readings share the top row and each keeps the row's height.
	function reading(column) {
		return Cells.box(screen.cell(0), [-1, -1, -1], [-1], column, 0)
	}

	// Where WeatherLayer's cards are asked to be while this context is on. The names are the
	// whole contract: nothing checks that a screen offers the boxes the layer looks for, and a
	// misspelt one is a card that never arrives.
	readonly property var weatherBoxes: ({
		temperature: screen.reading(0),
		temperatureChart: screen.cell(1),
		rainChance: screen.cell(2)
	})

	SceneElement {
		id: wind
		box: screen.reading(1)

		WindCard { anchors.fill: parent }

		states: [
			State { name: "cameras"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 120 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 520
						easing.type: Easing.OutCubic
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
				NumberAnimation {
					properties: "offsetX,opacity"
					duration: 340
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: conditions
		box: screen.reading(2)

		ConditionsCard { anchors.fill: parent }

		states: [
			State { name: "cameras"; PropertyChanges { target: conditions; offsetX: 900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: conditions; offsetX: 900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: conditions; offsetX: 900; opacity: 0 } },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings"; PropertyChanges { target: conditions; offsetX: 900; opacity: 0 } },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 200 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 520
						easing.type: Easing.OutCubic
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
				NumberAnimation {
					properties: "offsetX,opacity"
					duration: 320
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cloud
		box: screen.cell(3)

		ChartCard {
			anchors.fill: parent
			title: "Cloud cover"
			series: Weather.cloudCoverForecast
			stroke: Theme.textDim
			unit: "%"
			decimals: 0
			fixedLow: 0
			fixedHigh: 100
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 280 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 520
						easing.type: Easing.OutCubic
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
				NumberAnimation {
					properties: "offsetX,opacity"
					duration: 300
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: fall
		box: screen.cell(4)

		// Millimetres, and the card two rows above is percent. The two are the weather screen's
		// one real trap: a chart of how much rain falls and a chart of how likely rain is look
		// identical and are never the same shape, so the titles and the units on the axis are
		// what tell them apart.
		ChartCard {
			anchors.fill: parent
			title: "Rain & snow"
			series: Weather.precipitationAmountForecast
			stroke: Theme.cool
			unit: "mm"
			decimals: 1
			fixedLow: 0
			minimumSpan: 2
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: screen.spans
				SequentialAnimation {
					PauseAnimation { duration: 360 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 520
						easing.type: Easing.OutBack
					}
				}
			},
			Transition {
				from: screen.spans; to: screen.away
				NumberAnimation {
					properties: "offsetX,opacity"
					duration: 300
					easing.type: Easing.InQuad
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}
}
