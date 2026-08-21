# Contexts

> Owns: src/qml/Nav.qml
> Owns: src/qml/Context.qml
> Owns: src/qml/SceneElement.qml
> Owns: src/qml/CamerasScreen.qml
> Owns: src/qml/DetailsScreen.qml
> Owns: src/qml/WeatherScreen.qml
> Owns: src/qml/WeatherLayer.qml
> Owns: src/qml/ForecastSpan.qml
> Owns: src/qml/Cells.qml
> See:  docs/scene.md docs/media.md docs/carousel.md

Exactly one context is ON; the left and right arrows cycle. Nothing draws a tab bar and
nothing is meant to: the only evidence a context exists is what it puts on the screen. The one
context where that is not true is [the carousel](docs/carousel.md), where all four screens are
on at once as miniatures and every screen therefore names `carousel` among its `contextIds`.

`Nav.cycle` is the ring the arrow keys walk and `Nav.contexts` is everything `goTo` accepts.
The two differ by `settings` and `carousel`, which are off the ring: `next()`/`previous()`
answer -1 for a context that is not on it and do nothing, which is what makes the arrows inert
in settings rather than jumping somewhere arbitrary.

Nine ids, and five screens. `details-24h` and `details-72h` are one screen seen over two forecast spans, which is why `Context.contextIds` is a list. Every element outside the weather charts gives all three the same pose, and that is the requirement rather than a shortcut: crossing between the spans must not move a box by a pixel, so the only thing animated in those six pairs is the width of the chart window.

Every context is instantiated once, at startup, and stays instantiated. That is not a
performance choice - a transition animates elements of both screens at the same time, so
both have to exist at the same time.

## Where an animation is written

On the element, never centrally. `SceneElement` carries no animation of its own; each use
declares one `State` per context id and one `Transition` per **ordered** pair. Two
consequences, and both are the point:

* `cameras -> details-24h` and the way back are separate entries and are free to look
  nothing alike. A `Transition` with `from` and `to` is not reversible.
* A pair that treats several ids alike names them on one side -
  `to: "details-24h,details-72h,details-7d"` - which is still every ordered pair, written
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
