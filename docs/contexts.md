# Contexts

> Owns: src/qml/Nav.qml
> Owns: src/qml/Context.qml
> Owns: src/qml/SceneElement.qml
> Owns: src/qml/CamerasScreen.qml
> Owns: src/qml/Cctv.qml
> Owns: src/qml/CompactScreen.qml
> Owns: src/qml/WeatherScreen.qml
> Owns: src/qml/WeatherLayer.qml
> Owns: src/qml/ForecastSpan.qml
> Owns: src/qml/Cells.qml
> See:  docs/scene.md docs/media.md docs/carousel.md docs/input.md

Exactly one context is ON; the two context keys cycle. Nothing draws a tab bar and
nothing is meant to: the only evidence a context exists is what it puts on the screen. The one
context where that is not true is [the carousel](docs/carousel.md), where all four screens are
on at once as miniatures and every screen therefore names `carousel` among its `contextIds`.

`Nav.cycle` is the ring those two keys walk and `Nav.contexts` is everything `goTo` accepts.
The two differ by `settings` and `carousel`, which are off the ring: `next()`/`previous()`
answer -1 for a context that is not on it and do nothing, which is what makes them inert
in settings rather than jumping somewhere arbitrary.

Seven ids and four screens, five of the ids on the ring. Two of the screens are two ids each -
`compact-24h`/`compact-72h` and `weather-72h`/`weather-7d` are one screen seen over two forecast
spans, which is why `Context.contextIds` is a list. Every element outside the weather charts
gives both ids of its screen the same pose, and that is the requirement rather than a shortcut:
crossing between the spans must not move a box by a pixel, so the only thing animated in those
four pairs is the width of the chart window.

Every context is instantiated once, at startup, and stays instantiated. That is not a
performance choice - a transition animates elements of both screens at the same time, so
both have to exist at the same time.

## Where an animation is written

On the element, never centrally. `SceneElement` carries no animation of its own; each use
declares one `State` per context id and one `Transition` per **ordered** pair. Two
consequences, and both are the point:

* `cameras -> compact-24h` and the way back are separate entries and are free to look
  nothing alike. A `Transition` with `from` and `to` is not reversible.
* A pair that treats several ids alike names them on one side -
  `to: "compact-24h,compact-72h"` - which is still every ordered pair, written
  once. Each screen keeps that list in one property so the ids are spelled once per file.
* Within one pair every element has its own duration, easing and `PauseAnimation` delay, so
  the outgoing and incoming screens overlap and stagger rather than moving as two blocks.

Interrupting is free and needs no code: a state change while a transition is running
retargets every animation from its current value, which is why a key pressed mid-flight
neither snaps nor queues.

## What is silent here

* **An element with no `State` for some context id keeps its base pose there.** Nothing
  warns. Both screens end up drawn on top of each other.
* **Never animate `x` or `y`.** Every element is a layout child and the layout reassigns
  both on the next relayout - somewhere between "the animation is ignored" and "the element
  never comes back". `offsetX`/`offsetY` drive a `Translate`, which no layout touches.
* **`Nav.settleMs` must be at least the longest transition in the scene.** It is what tells
  an OFF context that the animation is over. Shorter, and a camera is disconnected part-way
  through its own exit - a stream that dies exactly when you look away from it.
* **`Nav.goTo` restarts the settle timer *before* assigning `current`, and the order is the
  whole of it.** `current` is what makes a `Context` stop being `on`, and `live` needs the
  transition; assign first and there is one evaluation pass in which neither holds, which
  tears every camera down and animates out five black tiles.
* **`live` asks which transition is running, not whether one is.** A span change restarts
  the same settle timer, so a `live` of `on || Nav.transitioning` would bring the cameras'
  sessions up for the length of an animation they take no part in - off screen, unseen, once
  per key press. `Nav.leaving` is what the screen tests itself against.
* **A `PropertyChanges` that must survive leaving its state needs `restoreEntryValues:
  false`.** The forecast span is one: restored, a week-wide chart snaps back to a day while
  it is still flying off the screen.
* **The two forecast screens do not carry the same spans** - the compact screen has no week
  and the weather screen has no day - so `Nav.lastSpan` alone is not a valid id. A card opened
  on `card + "-" + lastSpan` reaches `goTo` with an id that is not in `contexts`, and what that
  looks like is a `down` key that does nothing and a chooser that will not close. `Nav.spanId`
  falls back to the card's first span, and is the whole of what stands between that and an
  application that appears to have frozen.

## The ids are one fact in three places

A context id is written in `Nav.contexts`, in a `Context`'s `contextIds`, and as a `State`
name on every element that animates - and nothing checks that they agree. Misspelt in the
first two it is a warning from `goTo`; misspelt in the third it is silent.

## The camera grid is fixed at five

`CamerasScreen` writes its five tiles out rather than driving a `Repeater`, because a
`Repeater` makes every delegate identical and every tile here is animated differently. A
sixth `camera-url` is configured and not drawn, and the sixth cell of the grid stays empty.

The camera rows are cut to the streams' 16:9 rather than filling the screen, and the height
that leaves over is the strip along the bottom that carries the clock and the tank. The cell
height is derived from the *screen's* width and not from the cell's: a `Layout.preferredHeight`
bound to the width the same layout assigns is a loop, and the layout settling it is not
something to depend on.

## Fullscreen is a zoom and not a context

A camera key grows one tile's `box` to the whole content rect and raises its `z`. `Cctv.zoom`
is which tile, and 0 is the grid. An eighth context id would be the obvious way to write it and
is the wrong one: every element of every screen would need a `State` for it - the silent
failure above - and the id would have to be threaded through `Nav.cycle`, `Nav.elsewhere` and
`Carousel.cardOf` as well, for something that is one screen's business. The other four tiles
keep their sessions while one fills the screen, so the way back costs no reconnect.

**`SceneElement.boxMs` is what animates a box, and it is off unless a use asks for it.**
`WeatherLayer` assigns `box` to hand a card between two screens and depends on that landing
inside one pass; animated, the cards would fly across the scene during the carousel hand-over.
The `Behavior` holds a `PropertyAnimation` because `box` is a rect - `NumberAnimation` does not
interpolate one, and what that looks like is a box that snaps with nothing said anywhere.

A camera key pressed on another context navigates to CCTV and `Cctv.returnTo` remembers where
from, so dropping the zoom goes back there rather than leaving somebody on a screen they only
asked one camera of. **Both halves of that are conditioned on the CCTV screen being the current
one**: off it a camera key is a way on and never a toggle, and the way back is not taken at all
- somebody who walked off with a context key has already chosen where they are, and a panel
that sent them back would read as one navigating itself. Only ring contexts are remembered;
`carousel` would be returned to with its strip standing wherever it was left.
See [input](docs/input.md).
