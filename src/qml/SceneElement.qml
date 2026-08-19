import QtQuick

// A thing that is animated in and out of a context, on its own terms.
//
// It carries no animation itself. Each use declares one `State` per context id and one
// `Transition` per ORDERED pair, which is what lets the hot water gauge slide left while a
// camera zooms at the viewer and the one beside it drops off the bottom.
//
// Two silent failures:
//
// A use that declares no State for some context id keeps its base pose there - both contexts
// end up drawn on top of each other, with no warning anywhere.
//
// Never animate `x` or `y`: every element here is a layout child and the layout reassigns
// both on the next relayout, which lands somewhere between "the animation is ignored" and
// "the element never comes back". offsetX/offsetY drive a Translate, which no layout touches.
Item {
	id: element

	property real offsetX: 0
	property real offsetY: 0

	state: Nav.current

	// An element that has faded out costs nothing further.
	visible: opacity > 0

	transform: Translate { x: element.offsetX; y: element.offsetY }
}
