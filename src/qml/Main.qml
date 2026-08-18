import QtQuick
import QtQuick.Window

Window {
	id: root

	// eglfs ignores this and takes the whole connector. It is the window size on a
	// desktop, and on both targets the aspect the scene is composed against.
	width: 1280
	height: 720
	visible: true
	color: "#101014"
	title: "qt-qml-hmi"

	SpinningTriangle {
		anchors.centerIn: parent
		side: Math.min(root.width, root.height) * 0.6
	}
}
