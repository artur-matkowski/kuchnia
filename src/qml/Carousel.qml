pragma Singleton
import QtQuick

// The chooser. One animated number - where the strip stands - and every miniature's geometry
// is a function of it.
//
// A singleton for the same reason Nav and ForecastSpan are: eighteen elements spread over four
// screens each ask where their screen's card is, and a strip position each of them owned a copy
// of is eighteen copies of one fact.
//
// The strip moves WITHIN the carousel context, which is why `position` is animated by a
// Behavior and not by a Transition. Nav.current does not change when left or right is pressed
// here, so there is no state change for a Transition to hang on and nothing would move.
//
// Nothing here resizes anything. A miniature is a whole screen, laid out at full size and put
// through a Scale by the CardFrame it is - a card whose width really were a third of the
// screen's would re-lay out every label and re-wrap every title inside it, and the arithmetic
// of five camera cells cut to 16:9 would be done against a width nobody is looking at.
QtObject {
	id: carousel

	// The strip, in order, looped. These are card names and not context ids: the details and
	// weather screens are three contexts each and one card each.
	readonly property var cards: ["cameras", "details", "weather", "settings"]

	// The scene's size, bound by Main.qml. Under eglfs the window takes the whole connector, so
	// this cannot be the 1366x768 the desktop window is pinned to.
	property real screenWidth: 1366
	property real screenHeight: 768

	// How large the centred card is against the screen it is a miniature of, how large its
	// neighbours are, and how far apart their centres sit. The pitch is half the screen, so the
	// two neighbours stand exactly half off each edge and the fourth card is off screen
	// entirely until the strip loops round to it.
	readonly property real centreScale: 0.6
	readonly property real flankScale: 0.34
	readonly property real pitch: carousel.screenWidth * 0.5

	// Where the strip stands, in cards. Not wrapped: it runs on in whichever direction it is
	// pushed, so a step from the last card to the first slides one place rather than winding
	// three places back. `slot` is what wraps.
	property real position: 0

	Behavior on position {
		id: slide
		NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
	}

	readonly property int selected:
		((Math.round(carousel.position) % carousel.cards.length) + carousel.cards.length)
			% carousel.cards.length

	// How far a card stands from the centre, signed and wrapped into +/- half the strip, and
	// continuous in `position` - which is what makes every miniature slide and grow rather than
	// step when the strip moves.
	function slot(card) {
		var n = carousel.cards.length
		var raw = carousel.cards.indexOf(card) - carousel.position
		return raw - n * Math.round(raw / n)
	}

	function shrink(card) {
		var t = Math.max(0, 1 - Math.abs(carousel.slot(card)))
		var ease = t * t * (3 - 2 * t)
		return carousel.flankScale + (carousel.centreScale - carousel.flankScale) * ease
	}

	// Where a card's top left corner sits, once the screen inside it has been shrunk about that
	// same corner.
	function cardX(card) {
		return carousel.screenWidth / 2 + carousel.slot(card) * carousel.pitch
			- carousel.screenWidth * carousel.shrink(card) / 2
	}

	function cardY(card) {
		return carousel.screenHeight / 2 - carousel.screenHeight * carousel.shrink(card) / 2
	}

	// Where a card comes in from and goes out to: its own place, pushed a whole screen further
	// out on the side it already stands on. A screen crossing that distance is a screen already
	// shrunk and already laid out, so it arrives as itself rather than assembling on the way -
	// which is the whole reason the carousel moves frames and not elements.
	function entryX(card) {
		return carousel.cardX(card)
			+ (carousel.slot(card) >= 0 ? 1 : -1) * carousel.screenWidth * 1.15
	}

	// The card the strip is standing on. It is the one that zooms rather than slides: opening
	// the carousel it is the screen being left, closing it the screen being opened.
	readonly property string focused: carousel.cards[carousel.selected]

	// Which card draws over which. The cards overlap at the edges and the centred one has to be
	// the one on top, so depth follows the distance from centre rather than the order the four
	// screens happen to be declared in.
	function depth(card) {
		return 10 - Math.abs(carousel.slot(card))
	}

	function cardOf(contextId) {
		if (contextId.indexOf("details") === 0)
			return "details"
		if (contextId.indexOf("weather") === 0)
			return "weather"
		if (contextId === "settings")
			return "settings"
		return "cameras"
	}

	// Which of the two weather cards WeatherLayer's three cards stand in while the chooser is
	// up. They are one instance each and both cards want them, so one card gets the originals
	// and the other gets CarouselWeather's copies - and this says which way round.
	//
	// It is LATCHED when the carousel opens and never follows the selection afterwards. Bound
	// to `focused` it would hand the cards back and forth every time the strip stepped past
	// one of the two, which is three cards jumping between miniatures while nothing is being
	// transitioned at all.
	//
	// What it buys: arriving from the weather screen the originals simply stay where they are
	// and that screen zooms out around them, instead of flying across the scene into the
	// compact card while their copies stand in the column they left.
	property string anchorCard: "details"

	// Opening centres the card you were already on, and does it without animating: the strip
	// has to be standing where the scene is arriving from, or every miniature slides sideways
	// during the zoom out.
	function open(fromContextId) {
		carousel.anchorCard = carousel.cardOf(fromContextId) === "weather" ? "weather" : "details"
		slide.enabled = false
		carousel.position = carousel.cards.indexOf(carousel.cardOf(fromContextId))
		slide.enabled = true
	}

	function step(delta) {
		carousel.position += delta
	}

	// Down. The two screens that carry a forecast open on the span last asked for, so the
	// screen that opens is the miniature that was being looked at.
	//
	// The hand-over is the first line of it. Picking one of the two weather-bearing screens
	// while the originals are standing in the other one moves them across first: `anchorCard`
	// changes, every binding that depends on it re-evaluates, and the originals and the copies
	// exchange cards. Nothing is rendered between that and the state change below - it is one
	// pass through the event loop, and the two sets are identical to look at - so what the eye
	// sees is a screen growing out of the miniature it was pointing at, rather than three cards
	// arriving from the miniature next to it.
	function confirm() {
		var card = carousel.cards[carousel.selected]
		if (card === "details" || card === "weather")
			carousel.anchorCard = card
		if (card === "details")
			Nav.goTo("details-" + Nav.lastSpan)
		else if (card === "weather")
			Nav.goTo("weather-" + Nav.lastSpan)
		else
			Nav.goTo(card)
	}
}
