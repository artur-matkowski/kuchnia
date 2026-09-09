import QtQuick
import Kuchnia

// The key bindings, one row per action. The rows are drawn in the order KeyBindings lists its
// actions and nothing checks that they agree: drawn in another order, the selection appears to
// jump about the screen. Two columns, walked column-major, and the two do not hold the same
// number of cards - see docs/settings.md.
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

	// One row per action, and the height a card needs to hold that many of them: the heading
	// strip, the margins, the rows and the gaps between them. Written out of the parts the way
	// Theme.readingRow is, because the heading does not scale with the rows. The fourth gap is
	// headroom - Card.contentTop measures its heading at runtime and this is only the type
	// scale's figure for it, and nothing in this scene clips: a card cut a pixel short is its
	// last row drawn over the card beneath it.
	readonly property int bindingRow: Math.round(Theme.fontBody * 1.8)

	function bindingCard(rows) {
		return Math.round(Theme.fontLabel * 1.2) + Theme.gap * 4
		     + rows * screen.bindingRow + (rows - 1) * Theme.gap
	}

	// Two row specs against one column spec, which is what puts three cards down the left and
	// two down the right. Equal thirds on the left would leave every card there four rows tall,
	// one short of the two that need five, so the gate's card - the only one with three - takes
	// a height cut to its own contents and the other two share what is left.
	readonly property int headingRow: Math.round(Theme.fontLabel * 1.6)
	readonly property var leftRows:  [screen.headingRow, -1, -1, screen.bindingCard(3)]
	readonly property var rightRows: [screen.headingRow, -1, -1]

	function cell(column, row) {
		return Cells.box(screen.content, [-1, -1],
		                 column === 0 ? screen.leftRows : screen.rightRows, column, row)
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
		height: screen.bindingRow
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
				text: !row.capturing ? (row.key.length > 0 ? row.key : "nieprzypisany")
				    : KeyBindings.refused.length > 0 ? KeyBindings.refused
				    : "naciśnij klawisz"
				color: !row.capturing ? (row.key.length > 0 ? Theme.text : Theme.textDim)
				     : KeyBindings.refused.length > 0 ? Theme.failed : Theme.accent
				font.pixelSize: Theme.fontLabel
				elide: Text.ElideRight
			}
		}
	}

	// The strip above the cards. It is a SceneElement and not a plain child of the screen: a
	// child of the Context keeps its base pose in every state, so it would stay on screen over
	// the cameras and the map while the cards it belongs to have slid away.
	SceneElement {
		id: heading
		box: Cells.box(screen.content, [-1, -1], screen.leftRows, 0, 0, 2, 1)

		Text {
			anchors { left: parent.left; leftMargin: Theme.gap; verticalCenter: parent.verticalCenter }
			text: "Ustawienia"
			color: Theme.text
			font.pixelSize: Theme.fontLabel
			font.bold: true
		}

		// Which build this is. The package's version, or the commit a desktop build was
		// configured at - see docs/packaging.md.
		Text {
			anchors { right: parent.right; rightMargin: Theme.gap; verticalCenter: parent.verticalCenter }
			text: "kuchnia " + App.version
			color: Theme.textDim
			font.pixelSize: Theme.fontLabel
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: heading; offsetX: -900; opacity: 0 } },
			State { name: "map"; PropertyChanges { target: heading; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: heading; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: heading; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: heading; offsetX: -900; opacity: 0 } },
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
		box: screen.cell(0, 1)

		Card {
			id: navKeysCard
			anchors.fill: parent
			title: "Nawigacja"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: navKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "context-previous" }
				BindingRow { action: "context-next" }
				BindingRow { action: "menu" }
				BindingRow { action: "confirm" }
				BindingRow { action: "refresh" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
			State { name: "map"; PropertyChanges { target: navKeys; offsetX: -900; opacity: 0 } },
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

	SceneElement {
		id: mapKeys
		box: screen.cell(0, 2)

		Card {
			id: mapKeysCard
			anchors.fill: parent
			title: "Mapa"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: mapKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "map-people" }
				BindingRow { action: "map-previous" }
				BindingRow { action: "map-next" }
				BindingRow { action: "map-zoom-in" }
				BindingRow { action: "map-zoom-out" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: mapKeys; offsetX: -900; opacity: 0 } },
			State { name: "map"; PropertyChanges { target: mapKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: mapKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: mapKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: mapKeys; offsetX: -900; opacity: 0 } },
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
		box: screen.cell(0, 3)

		Card {
			id: gateKeysCard
			anchors.fill: parent
			title: "Brama"

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
			State { name: "map"; PropertyChanges { target: gateKeys; offsetX: -900; opacity: 0 } },
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
		id: soundKeys
		box: screen.cell(1, 1)

		Card {
			id: soundKeysCard
			anchors.fill: parent
			title: "Dźwięk"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: soundKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "radio-play-stop" }
				BindingRow { action: "radio-next" }
				BindingRow { action: "radio-previous" }
				BindingRow { action: "volume-up" }
				BindingRow { action: "volume-down" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: soundKeys; offsetX: -900; opacity: 0 } },
			State { name: "map"; PropertyChanges { target: soundKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: soundKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: soundKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: soundKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			CarouselIn {},
			CarouselOut {}
		]
	}

	SceneElement {
		id: cameraKeys
		box: screen.cell(1, 2)

		Card {
			id: cameraKeysCard
			anchors.fill: parent
			title: "Kamery"

			Column {
				anchors { fill: parent; margins: Theme.gap; topMargin: cameraKeysCard.contentTop }
				spacing: Theme.gap

				BindingRow { action: "camera-1" }
				BindingRow { action: "camera-2" }
				BindingRow { action: "camera-3" }
				BindingRow { action: "camera-4" }
				BindingRow { action: "camera-5" }
				BindingRow { action: "camera-grid" }
			}
		}

		states: [
			State { name: "cameras"; PropertyChanges { target: cameraKeys; offsetX: -900; opacity: 0 } },
			State { name: "map"; PropertyChanges { target: cameraKeys; offsetX: -900; opacity: 0 } },
			State { name: "compact-72h"; PropertyChanges { target: cameraKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-72h"; PropertyChanges { target: cameraKeys; offsetX: -900; opacity: 0 } },
			State { name: "weather-7d"; PropertyChanges { target: cameraKeys; offsetX: -900; opacity: 0 } },
			State { name: "settings" },
			State { name: "carousel" }
		]

		transitions: [
			CarouselIn {},
			CarouselOut {}
		]
	}
}
