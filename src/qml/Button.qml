import QtQuick

// A button, rather than QtQuick.Controls: the target ships no style, and the whole of what is
// wanted here is a rectangle that reports a press.
//
// `enabled` is Item's own and is not redeclared - a MouseArea inside a disabled Item stops
// accepting events on its own.
Rectangle {
	id: root

	property string text: ""

	signal clicked()

	// Implicit sizes only, and no width/height of its own: in a layout the layout sizes it,
	// and a button that assigns its own size is a button that never fills the box it is in.
	implicitWidth: label.implicitWidth + Theme.fontBody * 2
	implicitHeight: Theme.fontBody * 2
	radius: 4
	color: !enabled ? Theme.surface : area.pressed ? Theme.accent : Theme.border
	border.color: enabled ? Theme.accent : Theme.border
	border.width: 1
	opacity: enabled ? 1.0 : 0.4

	Text {
		id: label
		anchors.centerIn: parent
		text: root.text
		color: Theme.text
		font.pixelSize: Theme.fontBody
	}

	MouseArea {
		id: area
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
