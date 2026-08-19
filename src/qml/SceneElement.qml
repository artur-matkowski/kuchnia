import QtQuick

// A thing that is animated in and out of a context, on its own terms.
//
// It carries no animation itself. Each use declares one `State` per context id and one
// `Transition` per ORDERED pair, which is what lets the hot water gauge slide left while a
// camera zooms at the viewer and the one beside it drops off the bottom.
//
// The carousel is the one context where an element has nothing of its own to do: there the
// whole screen is shrunk and slid into a card by the CardFrame it sits in, and an element that
// animated itself as well would come apart from the screen it belongs to. Its `carousel` State
// is therefore empty - the home pose - and its two carousel Transitions only snap it there.
//
// Two silent failures:
//
// A use that declares no State for some context id keeps its base pose there - both contexts
// end up drawn on top of each other, with no warning anywhere.
//
// Leave a context by moving offsetX/offsetY, not by assigning x or y. Those two are bound to
// `box`, and a State that assigns either replaces that binding for as long as the State is
// held: the element stops following its screen's arithmetic and nothing says so. The one
// thing that may be assigned is `box` itself, which is what a card does when it belongs to
// two screens and has to migrate between them - see WeatherLayer.qml.
Item {
	id: element

	// Where this element sits, in the screen's coordinates, computed by that screen through
	// Cells. A rectangle rather than four numbers so that a move is one animated property.
	property rect box: Qt.rect(0, 0, 0, 0)

	property real offsetX: 0
	property real offsetY: 0

	x: box.x
	y: box.y
	width: box.width
	height: box.height

	state: Nav.current

	// An element that has faded out costs nothing further.
	visible: opacity > 0

	transform: Translate { x: element.offsetX; y: element.offsetY }
}
