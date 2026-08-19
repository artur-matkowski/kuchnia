import QtQuick
import QtQuick.Layouts

// Everything that is not a camera: the weather, the gate, the tank's history and the radio.
// Each panel is its own SceneElement, so the way this screen assembles itself is written
// panel by panel and does not have to mirror the way the cameras leave.
//
// It is three contexts, not one: details-24h, details-72h and details-7d differ in the width
// of the forecast window and in nothing else. Every element here therefore gives all three
// the same pose, and the only thing animated between them is the weather panel's span - the
// boxes must not move by a pixel when the range changes.
Context {
	id: screen

	contextIds: ["details-24h", "details-72h", "details-7d"]

	// The three ids as one Transition side. The States below still name them one at a time -
	// a State name is a literal - but a pair that treats the three alike says so once.
	readonly property string spans: "details-24h,details-72h,details-7d"

	GridLayout {
		anchors.fill: parent
		anchors.margins: Theme.gap
		columns: 2
		rows: 2
		columnSpacing: Theme.gap
		rowSpacing: Theme.gap

		SceneElement {
			id: weather
			Layout.fillWidth: true
			Layout.fillHeight: true

			// The width of the forecast window. It is a property of the element and not of the
			// panel because it is what the state machine animates; the panel only reads it.
			property real spanMs: 24 * 3600 * 1000

			WeatherPanel {
				anchors.fill: parent
				spanMs: weather.spanMs
				// Derived from the id rather than spelled a fourth time. It changes the instant
				// a key is pressed, while the range is still easing towards it.
				spanLabel: Nav.current.indexOf("details-") === 0 ? Nav.current.substring(8) : ""
			}

			states: [
				State {
					name: "cameras"
					PropertyChanges { target: weather; offsetX: -1400; opacity: 0 }
				},
				// restoreEntryValues is false on all three: leaving for the cameras would
				// otherwise restore the base 24h, so a week-wide chart would snap shut while it
				// is still flying off the screen.
				State {
					name: "details-24h"
					PropertyChanges { target: weather; spanMs: 24 * 3600 * 1000; restoreEntryValues: false }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: weather; spanMs: 72 * 3600 * 1000; restoreEntryValues: false }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: weather; spanMs: 168 * 3600 * 1000; restoreEntryValues: false }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
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
					from: screen.spans; to: "cameras"
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 380
						easing.type: Easing.InCubic
					}
				},
				// The six ordered span pairs, written out one by one because they are the point
				// of the three contexts. Nothing but spanMs is named in any of them: a second
				// property here is a box that moves.
				Transition {
					from: "details-24h"; to: "details-72h"
					NumberAnimation { properties: "spanMs"; duration: 560; easing.type: Easing.OutCubic }
				},
				Transition {
					from: "details-24h"; to: "details-7d"
					NumberAnimation { properties: "spanMs"; duration: 720; easing.type: Easing.OutCubic }
				},
				Transition {
					from: "details-72h"; to: "details-7d"
					NumberAnimation { properties: "spanMs"; duration: 560; easing.type: Easing.OutCubic }
				},
				Transition {
					from: "details-72h"; to: "details-24h"
					NumberAnimation { properties: "spanMs"; duration: 520; easing.type: Easing.InOutCubic }
				},
				Transition {
					from: "details-7d"; to: "details-72h"
					NumberAnimation { properties: "spanMs"; duration: 520; easing.type: Easing.InOutCubic }
				},
				Transition {
					from: "details-7d"; to: "details-24h"
					NumberAnimation { properties: "spanMs"; duration: 680; easing.type: Easing.InOutCubic }
				}
			]
		}

		SceneElement {
			id: gate
			Layout.fillWidth: true
			Layout.fillHeight: true

			GatePanel { anchors.fill: parent }

			states: [
				State {
					name: "cameras"
					PropertyChanges { target: gate; offsetY: -820; opacity: 0 }
				},
				State { name: "details-24h" },
				State { name: "details-72h" },
				State { name: "details-7d" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
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
					from: screen.spans; to: "cameras"
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
			Layout.fillWidth: true
			Layout.fillHeight: true

			HotWaterPanel { anchors.fill: parent }

			states: [
				State {
					name: "cameras"
					PropertyChanges { target: hotWater; scale: 0.8; opacity: 0 }
				},
				State { name: "details-24h" },
				State { name: "details-72h" },
				State { name: "details-7d" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
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
					from: screen.spans; to: "cameras"
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
			Layout.fillWidth: true
			Layout.fillHeight: true

			RadioPanel { anchors.fill: parent }

			states: [
				State {
					name: "cameras"
					PropertyChanges { target: radio; offsetY: 820; opacity: 0 }
				},
				State { name: "details-24h" },
				State { name: "details-72h" },
				State { name: "details-7d" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
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
					from: screen.spans; to: "cameras"
					NumberAnimation {
						properties: "offsetY,opacity"
						duration: 340
						easing.type: Easing.InQuad
					}
				}
			]
		}
	}
}
