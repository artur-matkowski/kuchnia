# The scene

> Owns: src/qml/Main.qml
> Owns: src/qml/Theme.qml
> Owns: src/qml/Card.qml
> Owns: src/qml/Button.qml
> Owns: src/qml/StatusBadge.qml
> Owns: src/qml/Clock.qml
> Owns: src/qml/LineChart.qml
> Owns: src/qml/Gauge.qml
> Owns: src/qml/GatePanel.qml
> Owns: src/qml/HotWaterPanel.qml
> Owns: src/qml/WeatherPanel.qml
> See:  docs/state.md docs/media.md docs/app.md

A clock, a row of camera tiles, and panels for the gate, the radio, the hot water tank and
the weather. The arrangement in `Main.qml` exists so that every pipe can be seen carrying
data at once; it is not a design and nothing depends on it.

`Window` sets 1280x720. Under `eglfs` that size is ignored and the window takes the whole
connector; it is the desktop window size, and on both targets the aspect the scene is laid
out against.

## Three names that are already taken

QML accepts a redeclared property silently and then behaves oddly somewhere else:

* **`state`** exists on every `Item`. `StatusBadge` calls its property `health` for that
  reason; a `property string state` would fight QML's own state machine.
* **`enabled`** exists on every `Item`. `Button` does not redeclare it — a `MouseArea` inside
  a disabled `Item` stops accepting events on its own.
* **`Layout.fillHeight` defaults to `true` for a nested layout** and to `false` only for a
  plain `Item`. Left alone, the rows in `Main.qml` each take the whole column and the panels
  at the bottom are laid out one pixel high, which reads as a rendering fault rather than a
  layout one. Both non-filling rows say so explicitly.

## Card has no default property

A `default property alias content: body.data` is the obvious way to write a frame, and it is
wrong here: the default property applies where a component is *defined* as well as where it
is used, so `Card`'s own title and badge land in the inner item — including the inner item
itself. Panels anchor below `contentTop` instead.

## Charts draw nothing when they have nothing

`LineChart` renders `no data` for an empty or single-point series. It must never fall back to
a flat line at zero: that is indistinguishable from a real reading, and the panel's status
badge is the only thing that would contradict it.

`_plot()` reads `plot.width` and `plot.height`, which is what makes the `PathPolyline`
binding re-evaluate on a resize — QML records every property read during an evaluation,
inside called functions included, so the dependency does not have to be named anywhere. A
version of that function that took the size as arguments would draw once and never again.

`Shape` renders through the scene graph. `Canvas` would not: it rasterises on the CPU, which
is the wrong thing to reach for on an image with no software fallback at all.

`minimumSpan` forces the vertical range open when the data is nearly flat, so a tank holding
steady renders as a steady line rather than as sensor noise magnified across the whole
height.

## The clock ticks off a timer

`Date()` is not a property, so a binding on it is evaluated once and never again — a clock
frozen at startup, with no error anywhere. The `Timer` in `Clock.qml` is what moves it.
