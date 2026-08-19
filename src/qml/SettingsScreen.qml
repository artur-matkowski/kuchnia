import QtQuick

// The settings screen, and it is a mockup: every row below is drawn and none of them do
// anything. What it is a mockup OF is the shape the real screen will have - an alternative key
// binding for each thing the panel can be told to do, blank until one is chosen, with the
// arrows working alongside whatever is bound here rather than being replaced by it.
//
// It is off the left/right ring on purpose - `settings` is not in Nav.cycle - so the carousel
// is the only way in and up is the only way out.
Context {
	id: screen

	contextIds: ["settings", "carousel"]
	card: "settings"

	// Every id that is not this screen and is not the carousel. The three cards leave for all
	// of them alike.
	readonly property string away: "cameras,details-24h,details-72h,details-7d,weather-24h,weather-72h,weather-7d"

	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	function cell(row) {
		return Cells.box(screen.content, [-1], [-1, -1, -1], 0, row)
	}

	// One row of the mockup: what can be bound, and what it is bound to. Nothing is, so every
	// slot reads as unset, which is what the real screen will show until somebody binds one.
	component BindingRow: Row {
		property string action: ""

		width: parent.width
		spacing: Theme.gap

		Text {
			width: parent.width * 0.6
			text: action
			color: Theme.text
			font.pixelSize: Theme.fontBody
			elide: Text.ElideRight
		}

		Rectangle {
			width: Theme.fontBody * 6
			height: Theme.fontBody * 1.6
			radius: 4
			color: "transparent"
			border.color: Theme.border
			border.width: 1

			Text {
				anchors.centerIn: parent
				text: "unbound"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}
		}
	}

	SceneElement {
		id: radioKeys
		box: screen.cell(0)

		Card {
			id: radioKeysCard
			anchors.fill: parent
			title: "Radio"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: radioKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "play / pause" }
				BindingRow { action: "next station" }
				BindingRow { action: "previous station" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-24h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: "settings"
				SequentialAnimation {
					PauseAnimation { duration: 0 }
					NumberAnimation { properties: "offsetX,opacity"; duration: 480; easing.type: Easing.OutCubic }
				}
			},
			Transition {
				from: "settings"; to: screen.away
				NumberAnimation { properties: "offsetX,opacity"; duration: 320; easing.type: Easing.InQuad }
			},
			// The carousel moves the whole screen and not its parts - see CardFrame.qml. These
			// two only put the element into its home pose, at no duration: on the way in the
			// screen is parked off the edge when they fire, and on the way out the pause holds
			// them until it is off the edge again.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: 500 }
					PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
				}
			}
		]
	}

	SceneElement {
		id: gateKeys
		box: screen.cell(1)

		Card {
			id: gateKeysCard
			anchors.fill: parent
			title: "Gate"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: gateKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "open" }
				BindingRow { action: "stop" }
				BindingRow { action: "close" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-24h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: "settings"
				SequentialAnimation {
					PauseAnimation { duration: 80 }
					NumberAnimation { properties: "offsetX,opacity"; duration: 480; easing.type: Easing.OutCubic }
				}
			},
			Transition {
				from: "settings"; to: screen.away
				NumberAnimation { properties: "offsetX,opacity"; duration: 320; easing.type: Easing.InQuad }
			},
			// The carousel moves the whole screen and not its parts - see CardFrame.qml. These
			// two only put the element into its home pose, at no duration: on the way in the
			// screen is parked off the edge when they fire, and on the way out the pause holds
			// them until it is off the edge again.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: 500 }
					PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
				}
			}
		]
	}

	SceneElement {
		id: navKeys
		box: screen.cell(2)

		Card {
			id: navKeysCard
			anchors.fill: parent
			title: "Navigation"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: navKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "previous context" }
				BindingRow { action: "next context" }
				BindingRow { action: "open the chooser" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-24h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-72h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "details-7d"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-24h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			Transition {
				from: screen.away; to: "settings"
				SequentialAnimation {
					PauseAnimation { duration: 160 }
					NumberAnimation { properties: "offsetX,opacity"; duration: 480; easing.type: Easing.OutCubic }
				}
			},
			Transition {
				from: "settings"; to: screen.away
				NumberAnimation { properties: "offsetX,opacity"; duration: 320; easing.type: Easing.InQuad }
			},
			// The carousel moves the whole screen and not its parts - see CardFrame.qml. These
			// two only put the element into its home pose, at no duration: on the way in the
			// screen is parked off the edge when they fire, and on the way out the pause holds
			// them until it is off the edge again.
			Transition {
				from: Nav.elsewhere; to: "carousel"
				PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
			},
			Transition {
				from: "carousel"; to: Nav.elsewhere
				SequentialAnimation {
					PauseAnimation { duration: 500 }
					PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
				}
			}
		]
	}
}
