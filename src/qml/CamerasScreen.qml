import QtQuick
import QtQuick.Layouts
import QtHmi

// Five cameras and the readouts, on one 3x2 grid. The sixth cell is where a sixth camera
// would have gone; at this resolution the tiles come out close enough to square that giving
// the spare cell to the clock and the tank costs nothing.
//
// The five tiles are written out rather than driven by a Repeater, and that is the point of
// this file: a Repeater makes every delegate identical, and every delegate here is animated
// differently. The count is fixed at five - a sixth camera-url is configured and not shown.
Context {
	id: screen

	contextIds: ["cameras"]

	// The three details ids as one Transition side. This screen leaves for all three alike and
	// comes back from all three alike; the States below still name them one at a time, because
	// a State name is a literal and an element with no State for an id is silently unanimated.
	readonly property string spans: "details-24h,details-72h,details-7d"

	GridLayout {
		anchors.fill: parent
		anchors.margins: Theme.gap
		columns: 3
		rows: 2
		columnSpacing: Theme.gap
		rowSpacing: Theme.gap

		SceneElement {
			id: cameraOne
			Layout.fillWidth: true
			Layout.fillHeight: true

			CameraTile {
				anchors.fill: parent
				url: Cameras.urls.length > 0 ? Cameras.urls[0] : ""
				label: "camera 1"
				active: screen.live
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					NumberAnimation {
						properties: "scale,opacity"
						duration: 550
						easing.type: Easing.InCubic
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					NumberAnimation {
						properties: "scale,opacity"
						duration: 450
						easing.type: Easing.OutCubic
					}
				}
			]
		}

		SceneElement {
			id: cameraTwo
			Layout.fillWidth: true
			Layout.fillHeight: true

			CameraTile {
				anchors.fill: parent
				url: Cameras.urls.length > 1 ? Cameras.urls[1] : ""
				label: "camera 2"
				active: screen.live
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					SequentialAnimation {
						PauseAnimation { duration: 60 }
						NumberAnimation {
							properties: "offsetY,opacity"
							duration: 480
							easing.type: Easing.InQuad
						}
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					SequentialAnimation {
						PauseAnimation { duration: 160 }
						NumberAnimation {
							properties: "offsetY,opacity"
							duration: 480
							easing.type: Easing.OutBack
						}
					}
				}
			]
		}

		SceneElement {
			id: cameraThree
			Layout.fillWidth: true
			Layout.fillHeight: true

			CameraTile {
				anchors.fill: parent
				url: Cameras.urls.length > 2 ? Cameras.urls[2] : ""
				label: "camera 3"
				active: screen.live
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					SequentialAnimation {
						PauseAnimation { duration: 60 }
						NumberAnimation {
							properties: "offsetY,opacity"
							duration: 480
							easing.type: Easing.InQuad
						}
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					SequentialAnimation {
						PauseAnimation { duration: 160 }
						NumberAnimation {
							properties: "offsetY,opacity"
							duration: 480
							easing.type: Easing.OutBack
						}
					}
				}
			]
		}

		SceneElement {
			id: cameraFour
			Layout.fillWidth: true
			Layout.fillHeight: true

			CameraTile {
				anchors.fill: parent
				url: Cameras.urls.length > 3 ? Cameras.urls[3] : ""
				label: "camera 4"
				active: screen.live
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					SequentialAnimation {
						PauseAnimation { duration: 120 }
						NumberAnimation {
							properties: "offsetX,opacity"
							duration: 460
							easing.type: Easing.InQuad
						}
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					SequentialAnimation {
						PauseAnimation { duration: 80 }
						NumberAnimation {
							properties: "offsetX,opacity"
							duration: 460
							easing.type: Easing.OutCubic
						}
					}
				}
			]
		}

		SceneElement {
			id: cameraFive
			Layout.fillWidth: true
			Layout.fillHeight: true

			CameraTile {
				anchors.fill: parent
				url: Cameras.urls.length > 4 ? Cameras.urls[4] : ""
				label: "camera 5"
				active: screen.live
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					SequentialAnimation {
						PauseAnimation { duration: 120 }
						NumberAnimation {
							properties: "offsetX,opacity"
							duration: 460
							easing.type: Easing.InQuad
						}
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					SequentialAnimation {
						PauseAnimation { duration: 80 }
						NumberAnimation {
							properties: "offsetX,opacity"
							duration: 460
							easing.type: Easing.OutCubic
						}
					}
				}
			]
		}

		SceneElement {
			id: readouts
			Layout.fillWidth: true
			Layout.fillHeight: true

			Card {
				id: readoutCard
				anchors.fill: parent
				title: "Now"
				// Status without the detail: the badge's text is not width-constrained, and
				// a connection error runs across this card's own title. The full detail is on
				// the hot water panel, which is wide enough to hold it.
				status: HotWater.status

				Column {
					anchors { fill: parent; margins: Theme.gap; topMargin: readoutCard.contentTop }
					spacing: Theme.gap

					Clock {}

					// No fallback reading. A tank whose panel is not live shows nothing rather
					// than a plausible number - see docs/state.md.
					Text {
						text: HotWater.live ? HotWater.current.toFixed(1) + "°C" : "--"
						color: HotWater.live ? Theme.hot : Theme.textDim
						font.pixelSize: 40
						font.bold: true
					}

					Text {
						text: "hot water"
						color: Theme.textDim
						font.pixelSize: 13
					}
				}
			}

			states: [
				State { name: "cameras" },
				State {
					name: "details-24h"
					PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
				},
				State {
					name: "details-72h"
					PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
				},
				State {
					name: "details-7d"
					PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
				}
			]

			transitions: [
				Transition {
					from: "cameras"; to: screen.spans
					NumberAnimation {
						properties: "scale,opacity"
						duration: 320
						easing.type: Easing.InQuad
					}
				},
				Transition {
					from: screen.spans; to: "cameras"
					SequentialAnimation {
						PauseAnimation { duration: 240 }
						NumberAnimation {
							properties: "scale,opacity"
							duration: 420
							easing.type: Easing.OutBack
						}
					}
				}
			]
		}
	}
}
