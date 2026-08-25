# The carousel

> Owns: src/qml/Carousel.qml
> Owns: src/qml/CardFrame.qml
> Owns: src/qml/CarouselWeather.qml
> Owns: src/qml/CarouselIn.qml
> Owns: src/qml/CarouselOut.qml
> See:  docs/contexts.md docs/scene.md docs/input.md

The chooser on the menu key. All five screens are on at once, laid out at full size and put
through one Scale each into a strip of miniatures; the two context keys slide the strip, always
looping, with the selected card centred; confirm opens the centred one. There is no cancel -
the menu key inside the carousel does nothing.

## Frames move, elements do not

This is the whole of the design and the reason `CardFrame` exists. Everywhere else an element
animates itself in and out of a context on its own terms, and if that were left to run here the
five screens would assemble out of loose parts: a gauge arriving from the left, a camera zooming
at the viewer, three weather cards crossing the screen, none of them agreeing on where their
screen is. In the carousel a screen moves as a screen.

So an element's `carousel` State is empty - the home pose - and its two carousel Transitions
have no duration. They fire while the frame that carries them is parked a whole screen outside
its card, which is what makes them invisible; on the way out a `PauseAnimation` holds them until
it is out there again. **That pause must stay shorter than the frame's own animation and than
`Nav.settleMs`.** Longer, and an element snaps to its exit pose in full view.

`Carousel.focused` is the card the strip stands on: opening, the screen being left; closing, the
screen being opened. It is the one frame that zooms rather than slides. Everything else starts
already shrunk and a screen further out than its card - `entryX` - and arrives already itself.

**On the way out the state has already reverted, and that is why the animations carry an
explicit `to`.** Left to animate at the reverted values, an unfocused frame flies back to full
size in full view. It is sent back out to where it came in from instead, and the `PropertyAction`
after it restores the identity once it is off the edge and nobody can see it happen.

## The three weather cards are on two cards at once

`WeatherLayer`'s three cards are one instance each - that is the point of that file - and the
compact and weather miniatures both want them. `CarouselWeather` is the second set, standing in
the weather miniature while the originals stand in the compact one. It is instantiated at
startup and hidden, not built when the carousel is asked for: three charts constructed in the
frame an animation starts in arrive late into a miniature that is already moving.

**Which set stands in which card is `Carousel.anchorCard`.** The originals hold the card of the
screen the chooser was opened from and the copies take the other one, so the two sets can never
be asked to fill the same column - and the screen that is being left zooms out around its own
cards instead of throwing them across the scene.

It moves once more, in `confirm()`, and that is the hand-over: picking the other of the two
weather-bearing screens exchanges the cards first, then changes the context. Nothing is drawn
between the two - one pass through the event loop, and the two sets are identical to look at -
so the screen grows out of the miniature that was being pointed at rather than out of the one
beside it. Anything more than those two moments, such as binding it to the selection, and the
three cards swap miniatures while the strip is merely stepping past them.

The copies come up at once on the way in - their card is never the one zooming - and on the way
out they are gone in the same frame if their own card is the one being opened, because the
originals are then on their way into that layout.

`WeatherLayer` overrides `CardFrame.focused`: it lives on two screens, so it is the frame in
flight whenever *either* of them is being opened or left, whichever card it is standing in.

## Settings

Off the ring - `settings` is in `Nav.contexts` and not in `Nav.cycle`, so the context keys do
nothing there and the carousel is the only way in and out. What the screen itself does is
[input](docs/input.md).

## What is silent here

* **A card name is a string in four places** - `Carousel.cards`, a screen's `card`, the two
  overrides in `WeatherLayer` and `CarouselWeather` - and nothing checks them. A misspelt one is
  a frame parked at slot 0 with everything else, drawn on top of the centred card.
* **The cameras stay connected while the chooser is up.** `carousel` is in every screen's
  `contextIds`, so `Context.live` holds - the CCTV miniature is moving pictures and coming back
  to it costs no reconnect. Taking it out of that list is five black tiles for six seconds on
  every visit to the chooser.
* **`Carousel.position` is never wrapped**, only `slot()` is. Wrapping it would turn the step
  from the last card to the first into three cards of travel backwards.
* **Nothing here resizes anything.** A miniature is a full-size screen through a Scale. A card
  that really were a third of the screen wide would re-lay out every label, re-wrap every title,
  and cut the camera cells to 16:9 of a width nobody is looking at.
