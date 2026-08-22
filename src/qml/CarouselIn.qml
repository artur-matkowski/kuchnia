import QtQuick
import QtHmi

// A SceneElement's way into the carousel, and there is nothing to it on purpose.
//
// The carousel moves whole screens and not their parts - see CardFrame.qml - so an element
// has only to be in its home pose by the time its frame arrives. This snaps it there while
// the frame is still parked a whole screen outside its card, where nobody can see it happen.
//
// Every screen's every element uses this pair, which is why it is two files rather than the
// same fifteen lines written eighteen times. WeatherLayer and CarouselWeather write their
// own: theirs really do move, because their cards migrate between two layouts.
Transition {
	from: Nav.elsewhere
	to: "carousel"

	PropertyAnimation { properties: "box,scale,opacity,offsetX,offsetY"; duration: 0 }
}
