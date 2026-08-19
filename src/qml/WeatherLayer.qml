import QtQuick
import QtHmi

// The three weather cards that are on two screens at once.
//
// They belong to neither screen, and that is the whole design. The details screen stacks them
// in one quarter of itself and the weather screen spreads them down half of it; crossing
// between the two must not fade them out and build them again, so there is one instance of
// each, drawn above both screens, animating its own box between the boxes the two screens ask
// for. A reading the eye is already following is carried across rather than interrupted.
//
// Both screens name their boxes `temperature`, `temperatureChart` and `rainChance`. Nothing
// checks that they do: a screen that spells one differently is a card that stays where it was,
// with no warning anywhere.
Item {
	id: layer

	// The two screens' boxes, wired by Main.qml - a card cannot ask a screen it is not inside
	// where to be.
	property var detailsBoxes: null
	property var weatherBoxes: null

	readonly property string spans: "details-24h,details-72h,details-7d"
	readonly property string weather: "weather-24h,weather-72h,weather-7d"

	anchors.fill: parent

	// Above both contexts, which own z 0 and 1. A card in flight belongs to neither screen.
	z: 2

	SceneElement {
		id: temperature

		// The base box is the details screen's, so only the weather ids need a State that says
		// otherwise. The cameras context names no box of its own and is animated out of
		// whichever one it was showing - see the transitions.
		box: layer.detailsBoxes.temperature

		TemperatureCard { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: temperature; offsetX: -1400; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: temperature; box: layer.weatherBoxes.temperature }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: temperature; box: layer.weatherBoxes.temperature }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: temperature; box: layer.weatherBoxes.temperature }
			}
		]

		transitions: [
			// The split, and the only pairs that migrate rather than move: the three cards
			// leave one column and arrive in another, staggered so they come apart instead of
			// travelling as a block. No opacity in either direction - a card that blinks here
			// is the exact thing this layer exists to prevent.
			Transition {
				from: layer.spans; to: layer.weather
				PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.InOutCubic }
			},
			Transition {
				from: layer.weather; to: layer.spans
				SequentialAnimation {
					PauseAnimation { duration: 120 }
					PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.InOutCubic }
				}
			},
			// The box is animated on the way to and from the cameras as well, because the
			// cameras context names none of its own: leaving the weather screen for it would
			// otherwise snap the card back into its details box before it had faded.
			Transition {
				from: "cameras"; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 200 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: "cameras"
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 380; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 380; easing.type: Easing.InCubic }
				}
			}
		]
	}

	SceneElement {
		id: temperatureChart

		box: layer.detailsBoxes.temperatureChart

		ChartCard {
			anchors.fill: parent
			title: ForecastSpan.label ? "Forecast · " + ForecastSpan.label : "Forecast"
			series: Weather.temperatureForecast
			stroke: Theme.cool
			unit: "°"
			decimals: 0
			minimumSpan: 5
		}

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: temperatureChart; offsetX: -1400; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: temperatureChart; box: layer.weatherBoxes.temperatureChart }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: temperatureChart; box: layer.weatherBoxes.temperatureChart }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: temperatureChart; box: layer.weatherBoxes.temperatureChart }
			}
		]

		transitions: [
			Transition {
				from: layer.spans; to: layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 60 }
					PropertyAnimation { properties: "box"; duration: 560; easing.type: Easing.InOutCubic }
				}
			},
			Transition {
				from: layer.weather; to: layer.spans
				SequentialAnimation {
					PauseAnimation { duration: 60 }
					PropertyAnimation { properties: "box"; duration: 540; easing.type: Easing.InOutCubic }
				}
			},
			Transition {
				from: "cameras"; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 260 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: "cameras"
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 360; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 360; easing.type: Easing.InCubic }
				}
			}
		]
	}

	SceneElement {
		id: rainChance

		box: layer.detailsBoxes.rainChance

		// Pinned to the whole scale. A probability chart that rescales itself puts 40% at the
		// top of the frame, which reads as a downpour from any distance at which the axis label
		// cannot be read.
		ChartCard {
			anchors.fill: parent
			title: "Rain chance"
			series: Weather.precipitationForecast
			stroke: Theme.accent
			unit: "%"
			decimals: 0
			fixedLow: 0
			fixedHigh: 100
		}

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: rainChance; offsetX: -1400; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State { name: "details-7d" },
			State {
				name: "weather-24h"
				PropertyChanges { target: rainChance; box: layer.weatherBoxes.rainChance }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: rainChance; box: layer.weatherBoxes.rainChance }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: rainChance; box: layer.weatherBoxes.rainChance }
			}
		]

		transitions: [
			Transition {
				from: layer.spans; to: layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 120 }
					PropertyAnimation { properties: "box"; duration: 600; easing.type: Easing.InOutCubic }
				}
			},
			Transition {
				from: layer.weather; to: layer.spans
				PropertyAnimation { properties: "box"; duration: 560; easing.type: Easing.InOutCubic }
			},
			Transition {
				from: "cameras"; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 320 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: "cameras"
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 340; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 340; easing.type: Easing.InCubic }
				}
			}
		]
	}
}
