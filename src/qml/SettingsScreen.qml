import QtQuick
import QtHmi

// The key bindings, one row per action. The rows are drawn in the order KeyBindings lists its
// actions and nothing checks that they agree: drawn in another order, the selection appears to
// jump about the screen.
//
// It is off the left/right ring on purpose - `settings` is not in Nav.cycle - so the carousel
// is the only way in and the menu key is the only way out.
Context {
	id: screen

	contextIds: ["settings", "carousel"]
	card: "settings"

	// The row the up and down keys are standing on. Main.qml drives both, because it owns the
	// keys and this screen never takes focus.
	property string selection: KeyBindings.actions[0]

	readonly property rect content: Qt.rect(Theme.gap, Theme.gap,
	                                        width - Theme.gap * 2, height - Theme.gap * 2)

	function cell(row) {
		return Cells.box(screen.content, [-1], [-1, -1, -1], 0, row)
	}

	function moveSelection(delta) {
		const rows = KeyBindings.actions
		const at = rows.indexOf(screen.selection)
		screen.selection = rows[(at + delta + rows.length) % rows.length]
	}

	function arm() {
		KeyBindings.capture(screen.selection)
	}

	// One action: what it is, and the key that runs it. An armed row shows what it is waiting
	// for, and says so rather than merely looking different - the panel is read from across a
	// room.
	component BindingRow: Rectangle {
		id: row

		property string action: ""

		readonly property bool selected:  screen.selection === row.action
		readonly property bool capturing: KeyBindings.capturing === row.action
		readonly property string key:     KeyBindings.keys[row.action]

		width: parent.width
		height: Theme.fontBody * 1.8
		radius: 4
		color: row.selected ? Theme.highlight : "transparent"

		// The id is written here and in KeyBindings' own table. Misspelt, it is a row with no
		// label that answers to nothing, which looks like a binding that will not take.
		Component.onCompleted:
			if (KeyBindings.actions.indexOf(row.action) < 0)
				console.warn("[settings] no such action: " + row.action)

		Text {
			anchors {
				left: parent.left
				leftMargin: Theme.gap
				verticalCenter: parent.verticalCenter
			}
			width: parent.width * 0.5
			text: KeyBindings.labels[row.action]
			color: row.selected ? Theme.text : Theme.textDim
			font.pixelSize: Theme.fontBody
			elide: Text.ElideRight
		}

		Rectangle {
			anchors {
				right: parent.right
				rightMargin: Theme.gap
				verticalCenter: parent.verticalCenter
			}
			width: Theme.fontBody * 11
			height: Theme.fontBody * 1.4
			radius: 4
			color: "transparent"
			border.color: row.capturing ? Theme.accent : Theme.border
			border.width: 1

			Text {
				anchors { fill: parent; margins: Theme.gap / 2 }
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				text: !row.capturing ? (row.key.length > 0 ? row.key : "unbound")
				    : KeyBindings.refused.length > 0 ? "held by " + KeyBindings.refused
				    : "press a key"
				color: !row.capturing ? (row.key.length > 0 ? Theme.text : Theme.textDim)
				     : KeyBindings.refused.length > 0 ? Theme.failed : Theme.accent
				font.pixelSize: Theme.fontLabel
				elide: Text.ElideRight
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

				BindingRow { action: "radio-play-stop" }
				BindingRow { action: "radio-next" }
				BindingRow { action: "radio-previous" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: radioKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			CarouselIn {},
			CarouselOut {}
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

				BindingRow { action: "gate-open" }
				BindingRow { action: "gate-stop" }
				BindingRow { action: "gate-close" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			CarouselIn {},
			CarouselOut {}
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

				BindingRow { action: "context-previous" }
				BindingRow { action: "context-next" }
				BindingRow { action: "menu" }
				BindingRow { action: "confirm" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-24h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			CarouselIn {},
			CarouselOut {}
		]
	}
}
