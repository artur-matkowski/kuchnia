import QtQuick

// One control made of several sections that touch, for a set of commands that are the same
// kind of thing - the gate's Open, Stop and Close. A section is unavailable when its command
// would be a no-op, and it stays in place rather than disappearing: a control that vanishes
// is indistinguishable from one that was never built.
//
// The model is a list of objects with `text` and `enabled`; `activated` carries the index.
// Sections are equal width and the bar fills whatever box it is given, because the whole
// point of it is to be hit from across the room.
Item {
	id: root

	property var model: []

	signal activated(int index)

	// The same height a Button answers with, so a bar of commands and a row of buttons on
	// two panels of one screen do not read as two different controls.
	implicitHeight: Theme.fontBody * 2

	Row {
		anchors.fill: parent
		// Zero, and the divider below is what separates two sections. Spacing here would make
		// this three buttons that happen to be near each other.
		spacing: 0

		Repeater {
			model: root.model

			Rectangle {
				id: section

				readonly property bool first: index === 0
				readonly property bool last: index === root.model.length - 1

				// Integer widths that still add up to the whole bar: dividing by the count and
				// rounding each section leaves a seam of background between two sections.
				width: Math.round((index + 1) * root.width / root.model.length)
				     - Math.round(index * root.width / root.model.length)
				height: root.height

				enabled: modelData.enabled
				color: !enabled ? Theme.surface : area.pressed ? Theme.accent : Theme.border
				opacity: enabled ? 1.0 : 0.35

				// Only the outer two corners of the bar are rounded. A Rectangle rounds all
				// four, so each section is drawn rounded and then squared off again on the side
				// that faces its neighbour by the patch below.
				radius: 4

				Rectangle {
					anchors.fill: parent
					anchors.leftMargin: section.first ? section.radius : 0
					anchors.rightMargin: section.last ? section.radius : 0
					color: section.color
				}

				// The seam between two sections.
				Rectangle {
					visible: !section.first
					anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
					width: 1
					color: Theme.background
				}

				Text {
					anchors.centerIn: parent
					text: modelData.text
					color: Theme.text
					font.pixelSize: Theme.fontBody
					font.bold: true
				}

				MouseArea {
					id: area
					anchors.fill: parent
					onClicked: root.activated(index)
				}
			}
		}
	}

	Rectangle {
		anchors.fill: parent
		color: "transparent"
		border.color: Theme.accent
		border.width: 1
		radius: 4
	}
}
