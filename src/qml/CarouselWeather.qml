import QtQuick
import QtHmi

// The second set of the three weather cards, and it exists for one reason: in the carousel the
// compact miniature and the weather miniature are on screen at the same time, and both of them
// show a temperature, a forecast and a rain chance. WeatherLayer's three cards can only be in
// one of the two - they are one instance each, which is the whole point of that file - so these
// three stand in the weather miniature while those three stand in the compact one.
//
// They are instantiated at startup and not built when the carousel is asked for. Three charts
// constructed in the frame an animation starts in is three cards arriving late into a miniature
// that is already moving.
//
// Their base pose is invisible, so every context but the carousel needs no pose of its own -
// the empty States below are still written out, because a state name QML cannot find is a state
// machine with nothing applied and a transition that never fires.
CardFrame {
	id: extra

	// Both screens' slots, wired by Main.qml: which of the two these copies fill depends on
	// which one the originals were left in, and that is not known until the chooser opens.
	property var compactBoxes: null
	property var weatherBoxes: null

	// Always the card the originals are NOT in. That is the whole of how the two sets are kept
	// apart: they can never be asked to stand in the same column, whichever screen the chooser
	// was opened from.
	card: Carousel.anchorCard === "weather" ? "compact" : "weather"

	baseZ: 2

	SceneElement {
		id: temperature
		box: extra.card === "weather"
			? extra.weatherBoxes.temperature : extra.compactBoxes.temperature

		// Invisible everywhere but in the carousel.
		opacity: 0

		TemperatureCard { anchors.fill: parent }

		states: [
			State { name: "cameras" },
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings" },
			State {
				name: "carousel"
				PropertyChanges { target: temperature; opacity: 1 }
			}
		]

		transitions: [
			// Nothing to move: these stand where their screen puts them and the frame carries
			// them. All they decide is when they are there.
			//
			// In: at once. Their card is never the one being zoomed out of - that one holds the
			// originals - so they come up inside a frame that is still off the edge.
			//
			// Out: at once if their own card is the one being opened, since the originals are
			// on their way into that layout and two temperatures crossing in the same column is
			// exactly what this file exists to avoid. Otherwise they are held until their frame
			// has slid off.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "opacity"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: extra.focused ? 0 : 500 }
					PropertyAnimation { properties: "opacity"; duration: 0 }
				}
			}
		]
	}

	SceneElement {
		id: forecast
		box: extra.card === "weather"
			? extra.weatherBoxes.temperatureChart : extra.compactBoxes.temperatureChart

		// Invisible everywhere but in the carousel.
		opacity: 0

		ForecastCard { anchors.fill: parent }

		states: [
			State { name: "cameras" },
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings" },
			State {
				name: "carousel"
				PropertyChanges { target: forecast; opacity: 1 }
			}
		]

		transitions: [
			// Nothing to move: these stand where their screen puts them and the frame carries
			// them. All they decide is when they are there.
			//
			// In: at once. Their card is never the one being zoomed out of - that one holds the
			// originals - so they come up inside a frame that is still off the edge.
			//
			// Out: at once if their own card is the one being opened, since the originals are
			// on their way into that layout and two temperatures crossing in the same column is
			// exactly what this file exists to avoid. Otherwise they are held until their frame
			// has slid off.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "opacity"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: extra.focused ? 0 : 500 }
					PropertyAnimation { properties: "opacity"; duration: 0 }
				}
			}
		]
	}

	SceneElement {
		id: rain
		box: extra.card === "weather"
			? extra.weatherBoxes.rainChance : extra.compactBoxes.rainChance

		// Invisible everywhere but in the carousel.
		opacity: 0

		RainChanceCard { anchors.fill: parent }

		states: [
			State { name: "cameras" },
			State { name: "compact-24h" },
			State { name: "compact-72h" },
			State { name: "weather-72h" },
			State { name: "weather-7d" },
			State { name: "settings" },
			State {
				name: "carousel"
				PropertyChanges { target: rain; opacity: 1 }
			}
		]

		transitions: [
			// Nothing to move: these stand where their screen puts them and the frame carries
			// them. All they decide is when they are there.
			//
			// In: at once. Their card is never the one being zoomed out of - that one holds the
			// originals - so they come up inside a frame that is still off the edge.
			//
			// Out: at once if their own card is the one being opened, since the originals are
			// on their way into that layout and two temperatures crossing in the same column is
			// exactly what this file exists to avoid. Otherwise they are held until their frame
			// has slid off.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "opacity"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: extra.focused ? 0 : 500 }
					PropertyAnimation { properties: "opacity"; duration: 0 }
				}
			}
		]
	}
}
