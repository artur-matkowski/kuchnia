import QtQuick
import QtQuick.Layouts

// Everything that is not a camera: the weather, the gate, the tank's history and the radio.
// Each panel is its own SceneElement, so the way this screen assembles itself is written
// panel by panel and does not have to mirror the way the cameras leave.
Context {
	id: screen

	contextId: "details"

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

			WeatherPanel { anchors.fill: parent }

			states: [
				State {
					name: "cameras"
					PropertyChanges { target: weather; offsetX: -1400; opacity: 0 }
				},
				State { name: "details" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: "details"
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
					from: "details"; to: "cameras"
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 380
						easing.type: Easing.InCubic
					}
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
				State { name: "details" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: "details"
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
					from: "details"; to: "cameras"
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
				State { name: "details" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: "details"
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
					from: "details"; to: "cameras"
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
				State { name: "details" }
			]

			transitions: [
				Transition {
					from: "cameras"; to: "details"
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
					from: "details"; to: "cameras"
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
