# Contexts

> Owns: src/qml/Nav.qml
> Owns: src/qml/Context.qml
> Owns: src/qml/SceneElement.qml
> Owns: src/qml/CamerasScreen.qml
> Owns: src/qml/DetailsScreen.qml
> See:  docs/scene.md docs/media.md

Exactly one context is ON; the arrow keys cycle. Nothing draws a tab bar and nothing is
meant to: the only evidence a context exists is what it puts on the screen.

Every context is instantiated once, at startup, and stays instantiated. That is not a
performance choice - a transition animates elements of both screens at the same time, so
both have to exist at the same time.

## Where an animation is written

On the element, never centrally. `SceneElement` carries no animation of its own; each use
declares one `State` per context id and one `Transition` per **ordered** pair. Two
consequences, and both are the point:

* `cameras -> details` and `details -> cameras` are separate entries and are free to look
  nothing alike. A `Transition` with `from` and `to` is not reversible.
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
  whole of it.** `current` is what makes a `Context` stop being `on`, and `live` is
  `on || transitioning`; assign first and there is one evaluation pass in which neither
  holds, which tears every camera down and animates out five black tiles.

## The ids are one fact in three places

A context id is written in `Nav.contexts`, as a `Context`'s `contextId`, and as a `State`
name on every element that animates - and nothing checks that they agree. Misspelt in the
first two it is a warning from `goTo`; misspelt in the third it is silent.

## The camera grid is fixed at five

`CamerasScreen` writes its five tiles out rather than driving a `Repeater`, because a
`Repeater` makes every delegate identical and every tile here is animated differently. A
sixth `camera-url` is configured and not drawn. The sixth cell of the 3x2 grid holds the
clock and the tank instead.
