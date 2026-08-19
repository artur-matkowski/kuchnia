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

	implicitWidth: label.implicitWidth + 24
	implicitHeight: 30
	width: implicitWidth
	height: implicitHeight
	radius: 3
	color: !enabled ? Theme.surface : area.pressed ? Theme.accent : Theme.border
	border.color: enabled ? Theme.accent : Theme.border
	border.width: 1
	opacity: enabled ? 1.0 : 0.4

	Text {
		id: label
		anchors.centerIn: parent
		text: root.text
		color: Theme.text
		font.pixelSize: 12
	}

	MouseArea {
		id: area
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
