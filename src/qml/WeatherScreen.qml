import QtQuick
import QtHmi

// The weather on its own, over three forecast spans like the details screen. The left column
// is not built here: those three boxes are slots, and what fills them is the three cards in
// WeatherLayer, which arrive from the details screen carrying the data they were already
// showing. This file owns the boxes and the three cards on the right.
Context {
	id: screen

	contextIds: ["weather-24h", "weather-72h", "weather-7d"]

	// Every id that is not this screen. The three cards on the right are off screen in all of
	// them and travel the same way in and out of each.
	readonly property string away: "cameras,details-24h,details-72h,details-7d"
	readonly property string spans: "weather-24h,weather-72h,weather-7d"

	// Everything inside the margin: two columns, a row for the readings and two for the charts.
	// The left column is the same division the details screen makes of its weather quadrant,
	// which is what lets the three cards grow into it rather than be re-laid-out inside it.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	function cell(column, row) {
		return Cells.box(screen.content, [-1, -1], [Theme.readingRow, -1, -1], column, row)
	}

	// Where WeatherLayer's cards are asked to be while this context is on. The names are the
	// whole contract: nothing checks that a screen offers the boxes the layer looks for, and a
	// misspelt one is a card that never arrives.
	readonly property var weatherBoxes: ({
		temperature: screen.cell(0, 0),
		temperatureChart: screen.cell(0, 1),
		rainChance: screen.cell(0, 2)
	})

	SceneElement {
		id: wind
		box: screen.cell(1, 0)

		WindCard { anchors.fill: parent }

		states: [
			State { name: "cameras"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: wind; offsetX: 900; opacity: 0 } },
			State { name: "weather-24h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" }
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
					duration: 340
					easing.type: Easing.InQuad
				}
			}
		]
	}

	SceneElement {
		id: cloud
		box: screen.cell(1, 1)

		ChartCard {
			anchors.fill: parent
			title: "Cloud cover"
			reading: Weather.live ? Weather.cloudCover.toFixed(0) + "%" : ""
			series: Weather.cloudCoverForecast
			stroke: Theme.textDim
			unit: "%"
			decimals: 0
			fixedLow: 0
			fixedHigh: 100
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: cloud; offsetX: 900; opacity: 0 } },
			State { name: "weather-24h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" }
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
			}
		]
	}

	SceneElement {
		id: fall
		box: screen.cell(1, 2)

		// Millimetres, and the card beside the rain chance is percent. The two are the
		// weather screen's one real trap: a chart of how much rain falls and a chart of
		// how likely rain is look identical and are never the same shape, so the titles
		// and the units on the axis are what tell them apart.
		ChartCard {
			anchors.fill: parent
			title: "Rain & snow"
			reading: Weather.live
				? Weather.rain.toFixed(1) + " mm · " + Weather.snowfall.toFixed(1) + " cm"
				: ""
			series: Weather.precipitationAmountForecast
			stroke: Theme.cool
			unit: "mm"
			decimals: 1
			fixedLow: 0
			minimumSpan: 2
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: fall; offsetX: 900; opacity: 0 } },
			State { name: "weather-24h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" }
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
			}
		]
	}
}
