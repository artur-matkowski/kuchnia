import QtQuick
import QtQuick.Layouts
import QtHmi

// Five cameras across two rows, and the clock and the tank on a strip under them. The camera
// cells are cut to 16:9 - the streams' own aspect - and the height that leaves over is what
// the strip is made of, which is why the readouts are as large as they are.
//
// The five tiles are written out rather than driven by a Repeater, and that is the point of
// this file: a Repeater makes every delegate identical, and every delegate here is animated
// differently. The count is fixed at five - a sixth camera-url is configured and not shown.
Context {
	id: screen

	contextIds: ["cameras", "carousel"]
	card: "cameras"

	// Every id that is not this screen, as one Transition side. This screen leaves for all five
	// alike and comes back from all five alike; the States below still name them one at a time,
	// because a State name is a literal and an element with no State for an id is silently
	// unanimated - both screens then draw on top of each other.
	readonly property string away: "compact-24h,compact-72h,weather-72h,weather-7d,settings"

	// Everything inside the margin. Every box on this screen is cut out of it.
	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	// The height of a camera cell, at the streams' own 16:9, from a column width the cell
	// arithmetic has not been asked for yet: two margins and two gaps come off the screen's
	// width and what is left divides by three. The rows below are given this height, so a
	// cellHeight read back out of a cell would be circular.
	readonly property real cellHeight: (width - Theme.gap * 4) / 3 * 9 / 16

	// Three columns, two rows of cameras, and the readouts strip taking whatever the two rows
	// leave - which is why the strip is as tall as it is and the readings on it as large.
	function cell(column, row, columnSpan) {
		return Cells.box(screen.content, [-1, -1, -1],
		                 [screen.cellHeight, screen.cellHeight, -1],
		                 column, row, columnSpan)
	}

	SceneElement {
		id: cameraOne
		box: screen.cell(0, 0)

		CameraTile {
			anchors.fill: parent
			url: Cameras.urls.length > 0 ? Cameras.urls[0] : ""
			label: "camera 1"
			active: screen.live
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: cameraOne; scale: 3.0; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
				NumberAnimation {
					properties: "scale,opacity"
					duration: 550
					easing.type: Easing.InCubic
				}
			},
			Transition {
				from: screen.away; to: "cameras"
				NumberAnimation {
					properties: "scale,opacity"
					duration: 450
					easing.type: Easing.OutCubic
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cameraTwo
		box: screen.cell(1, 0)

		CameraTile {
			anchors.fill: parent
			url: Cameras.urls.length > 1 ? Cameras.urls[1] : ""
			label: "camera 2"
			active: screen.live
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: cameraTwo; offsetY: -820; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
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
				from: screen.away; to: "cameras"
				SequentialAnimation {
					PauseAnimation { duration: 160 }
					NumberAnimation {
						properties: "offsetY,opacity"
						duration: 480
						easing.type: Easing.OutBack
					}
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cameraThree
		box: screen.cell(2, 0)

		CameraTile {
			anchors.fill: parent
			url: Cameras.urls.length > 2 ? Cameras.urls[2] : ""
			label: "camera 3"
			active: screen.live
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: cameraThree; offsetY: 820; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
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
				from: screen.away; to: "cameras"
				SequentialAnimation {
					PauseAnimation { duration: 160 }
					NumberAnimation {
						properties: "offsetY,opacity"
						duration: 480
						easing.type: Easing.OutBack
					}
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cameraFour
		box: screen.cell(0, 1)

		CameraTile {
			anchors.fill: parent
			url: Cameras.urls.length > 3 ? Cameras.urls[3] : ""
			label: "camera 4"
			active: screen.live
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: cameraFour; offsetX: -1400; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
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
				from: screen.away; to: "cameras"
				SequentialAnimation {
					PauseAnimation { duration: 80 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 460
						easing.type: Easing.OutCubic
					}
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cameraFive
		box: screen.cell(1, 1)

		CameraTile {
			anchors.fill: parent
			url: Cameras.urls.length > 4 ? Cameras.urls[4] : ""
			label: "camera 5"
			active: screen.live
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: cameraFive; offsetX: 1400; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
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
				from: screen.away; to: "cameras"
				SequentialAnimation {
					PauseAnimation { duration: 80 }
					NumberAnimation {
						properties: "offsetX,opacity"
						duration: 460
						easing.type: Easing.OutCubic
					}
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: readouts
		box: screen.cell(0, 2, 3)

		Card {
			id: readoutCard
			anchors.fill: parent
			title: "Now"
			// Status without the detail: the badge's text is not width-constrained, and
			// a connection error runs across this card's own title. The full detail is on
			// the hot water panel, which is wide enough to hold it.
			status: HotWater.status

			RowLayout {
				anchors { fill: parent; margins: Theme.gap; topMargin: readoutCard.contentTop }
				spacing: Theme.gap * 4

				Clock { Layout.alignment: Qt.AlignVCenter }

				Column {
					Layout.fillWidth: true
					Layout.alignment: Qt.AlignVCenter

					// No fallback reading. A tank whose panel is not live shows nothing
					// rather than a plausible number - see docs/state.md.
					Text {
						text: HotWater.live ? HotWater.current.toFixed(1) + "°C" : "--"
						color: HotWater.live ? Theme.hot : Theme.textDim
						font.pixelSize: Theme.fontHero
						font.bold: true
					}

					Text {
						text: "hot water"
						color: Theme.textDim
						font.pixelSize: Theme.fontBody
					}
				}
			}
		}

		states: [
			State { name: "cameras" },
			State {
				name: "compact-24h"
				PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
			},
			State {
				name: "compact-72h"
				PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
			},
			State {
				name: "weather-72h"
				PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
			},
			State {
				name: "weather-7d"
				PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
			},
			State {
				name: "settings"
				PropertyChanges { target: readouts; scale: 0.85; opacity: 0 }
			},
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: "cameras"; to: screen.away
				NumberAnimation {
					properties: "scale,opacity"
					duration: 320
					easing.type: Easing.InQuad
				}
			},
			Transition {
				from: screen.away; to: "cameras"
				SequentialAnimation {
					PauseAnimation { duration: 240 }
					NumberAnimation {
						properties: "scale,opacity"
						duration: 420
						easing.type: Easing.OutBack
					}
				}
			},
			CarouselIn {},
			CarouselOut {}
		]
	}
}
