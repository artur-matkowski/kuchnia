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
CardFrame {
	id: layer

	// The two screens' boxes, wired by Main.qml - a card cannot ask a screen it is not inside
	// where to be.
	property var detailsBoxes: null
	property var weatherBoxes: null

	readonly property string spans: "details-24h,details-72h"
	readonly property string weather: "weather-72h,weather-7d"

	// The two contexts these cards are not on at all. Settings leaves them exactly the way the
	// cameras do.
	readonly property string offIds: "cameras,settings"

	// Whichever of their two screens the chooser was opened from is the card they stay in, so
	// that screen zooms out around them and they never cross the scene to reach a miniature.
	// Carousel.anchorCard is latched at that moment; the copies take the other card.
	card: Carousel.anchorCard

	// And they are in flight whenever EITHER of the two screens they belong to is the one being
	// opened or left: the three cards migrate between those two layouts, so a step between the
	// carousel and the weather screen moves them as surely as a step to the compact one does.
	focused: Carousel.focused === "details" || Carousel.focused === "weather"

	// Above both contexts, which own z 0 and 1. A card in flight belongs to neither screen.
	baseZ: 2

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
			State {
				name: "weather-72h"
				PropertyChanges { target: temperature; box: layer.weatherBoxes.temperature }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: temperature; box: layer.weatherBoxes.temperature }
			},
			State {
				name: "settings"
				PropertyChanges { target: temperature; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "carousel"
				PropertyChanges {
					target: temperature
					box: Carousel.anchorCard === "weather"
						? layer.weatherBoxes.temperature : layer.detailsBoxes.temperature
				}
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
				from: layer.offIds; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 200 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: layer.offIds
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 380; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 380; easing.type: Easing.InCubic }
				}
			},
			// These three are the one element in the scene the carousel really moves: the
			// compact miniature is where they stand, and both screens they belong to are cards
			// of their own, so a step between the carousel and either of them is a migration
			// between two layouts and not just a change of pose - hence `focused`.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation {
					properties: "box,scale,opacity,offsetX,offsetY"
					duration: layer.focused ? 540 : 0
					easing.type: Easing.InOutCubic
				}
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: layer.focused ? 0 : 500 }
					PropertyAnimation {
						properties: "box,scale,opacity,offsetX,offsetY"
						duration: layer.focused ? 520 : 0
						easing.type: Easing.InOutCubic
					}
				}
			}
		]
	}

	SceneElement {
		id: temperatureChart

		box: layer.detailsBoxes.temperatureChart

		ForecastCard { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: temperatureChart; offsetX: -1400; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State {
				name: "weather-72h"
				PropertyChanges { target: temperatureChart; box: layer.weatherBoxes.temperatureChart }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: temperatureChart; box: layer.weatherBoxes.temperatureChart }
			},
			State {
				name: "settings"
				PropertyChanges { target: temperatureChart; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "carousel"
				PropertyChanges {
					target: temperatureChart
					box: Carousel.anchorCard === "weather"
						? layer.weatherBoxes.temperatureChart : layer.detailsBoxes.temperatureChart
				}
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
				from: layer.offIds; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 260 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: layer.offIds
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 360; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 360; easing.type: Easing.InCubic }
				}
			},
			// These three are the one element in the scene the carousel really moves: the
			// compact miniature is where they stand, and both screens they belong to are cards
			// of their own, so a step between the carousel and either of them is a migration
			// between two layouts and not just a change of pose - hence `focused`.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation {
					properties: "box,scale,opacity,offsetX,offsetY"
					duration: layer.focused ? 540 : 0
					easing.type: Easing.InOutCubic
				}
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: layer.focused ? 0 : 500 }
					PropertyAnimation {
						properties: "box,scale,opacity,offsetX,offsetY"
						duration: layer.focused ? 520 : 0
						easing.type: Easing.InOutCubic
					}
				}
			}
		]
	}

	SceneElement {
		id: rainChance

		box: layer.detailsBoxes.rainChance

		RainChanceCard { anchors.fill: parent }

		states: [
			State {
				name: "cameras"
				PropertyChanges { target: rainChance; offsetX: -1400; opacity: 0 }
			},
			State { name: "details-24h" },
			State { name: "details-72h" },
			State {
				name: "weather-72h"
				PropertyChanges { target: rainChance; box: layer.weatherBoxes.rainChance }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: rainChance; box: layer.weatherBoxes.rainChance }
			},
			State {
				name: "settings"
				PropertyChanges { target: rainChance; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "carousel"
				PropertyChanges {
					target: rainChance
					box: Carousel.anchorCard === "weather"
						? layer.weatherBoxes.rainChance : layer.detailsBoxes.rainChance
				}
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
				from: layer.offIds; to: layer.spans + "," + layer.weather
				SequentialAnimation {
					PauseAnimation { duration: 320 }
					ParallelAnimation {
						PropertyAnimation { properties: "box"; duration: 520; easing.type: Easing.OutCubic }
						NumberAnimation { properties: "offsetX,opacity"; duration: 520; easing.type: Easing.OutCubic }
					}
				}
			},
			Transition {
				from: layer.spans + "," + layer.weather; to: layer.offIds
				ParallelAnimation {
					PropertyAnimation { properties: "box"; duration: 340; easing.type: Easing.InCubic }
					NumberAnimation { properties: "offsetX,opacity"; duration: 340; easing.type: Easing.InCubic }
				}
			},
			// These three are the one element in the scene the carousel really moves: the
			// compact miniature is where they stand, and both screens they belong to are cards
			// of their own, so a step between the carousel and either of them is a migration
			// between two layouts and not just a change of pose - hence `focused`.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation {
					properties: "box,scale,opacity,offsetX,offsetY"
					duration: layer.focused ? 540 : 0
					easing.type: Easing.InOutCubic
				}
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: layer.focused ? 0 : 500 }
					PropertyAnimation {
						properties: "box,scale,opacity,offsetX,offsetY"
						duration: layer.focused ? 520 : 0
						easing.type: Easing.InOutCubic
					}
				}
			}
		]
	}
}
