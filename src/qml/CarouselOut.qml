import QtQuick
import QtHmi

// A SceneElement's way out of the carousel - see CarouselIn.qml for why there is no motion in
// either.
//
// The pause is the whole of this file. It holds the element at its carousel pose until the
// frame carrying it is back outside its card, and it MUST stay shorter than the frame's own
// animation in CardFrame.qml and than Nav.settleMs. Longer, and an element snaps to its exit
// pose in full view.
Transition {
	from: "carousel"
	to: Nav.elsewhere

	SequentialAnimation {
		PauseAnimation { duration: 500 }
		PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
	}
}
