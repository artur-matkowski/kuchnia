import QtQuick

// The wall clock. Ticks off a Timer rather than a binding, because there is nothing for a
// binding to depend on - Date() is not a property and QML will never re-evaluate it.
Column {
	id: root

	property date now: new Date()

	Timer {
		interval: 1000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.now = new Date()
	}

	Text {
		text: Qt.formatDateTime(root.now, "HH:mm")
		color: Theme.text
		font.pixelSize: Theme.fontHero
		font.bold: true
	}

	Text {
		text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
		color: Theme.textDim
		font.pixelSize: Theme.fontBody
	}
}
