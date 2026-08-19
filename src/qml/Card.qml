import QtQuick

// A titled frame with a status line. Panels put their own content in it and anchor below
// contentTop.
//
// No `default property alias content` here, tempting as it is: a default alias pointing at an
// inner Item captures the frame's own title and badge as well, since the default property
// applies where a component is defined and not only where it is used - the inner Item ends
// up a child of itself.
Rectangle {
	id: root

	property string title: ""
	property string status: ""
	property string statusDetail: ""

	// Where a panel's content starts. Below the heading, inside the margin.
	readonly property real contentTop: heading.height + Theme.gap * 2

	color: Theme.surface
	border.color: Theme.border
	border.width: 1
	radius: 4

	Text {
		id: heading
		anchors { left: parent.left; top: parent.top; margins: Theme.gap }
		text: root.title
		color: Theme.text
		font.pixelSize: Theme.fontLabel
		font.bold: true
	}

	StatusBadge {
		anchors { right: parent.right; top: parent.top; margins: Theme.gap }
		// Whatever the title leaves. Unbounded, a connection error runs across the title.
		maximumWidth: root.width - heading.width - Theme.gap * 3
		visible: root.status.length > 0
		health: root.status
		detail: root.statusDetail
	}
}
