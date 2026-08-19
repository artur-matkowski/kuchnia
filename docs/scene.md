# The scene

> Owns: src/qml/Main.qml
> Owns: src/qml/Theme.qml
> Owns: src/qml/Card.qml
> Owns: src/qml/Button.qml
> Owns: src/qml/SegmentedBar.qml
> Owns: src/qml/StatusBadge.qml
> Owns: src/qml/Clock.qml
> Owns: src/qml/LineChart.qml
> Owns: src/qml/Gauge.qml
> Owns: src/qml/GatePanel.qml
> Owns: src/qml/HotWaterPanel.qml
> Owns: src/qml/WeatherPanel.qml
> See:  docs/state.md docs/media.md docs/app.md docs/contexts.md

The panels the screens are assembled from - the clock, the gauge, the charts, the gate and
the radio - and the frame they all sit in. Which panel is on which screen, and how it gets
there, is [contexts](docs/contexts.md).

`Main.qml` is only the shell: the geometry, the focus and the arrow keys. It owns no layout.

`Window` is pinned to 1366x768, the panel the scene is composed against 1:1, so a desktop
window shows what the board will show rather than an approximation of it. Under `eglfs` the
size is ignored entirely and the window takes the whole connector.

## Three names that are already taken

QML accepts a redeclared property silently and then behaves oddly somewhere else:

* **`state`** exists on every `Item`. `StatusBadge` calls its property `health` for that
  reason; a `property string state` would fight QML's own state machine.
* **`enabled`** exists on every `Item`. `Button` does not redeclare it — a `MouseArea` inside
  a disabled `Item` stops accepting events on its own, which is also what makes a
  `SegmentedBar` section unavailable.
* **`Layout.fillHeight` defaults to `true` for a nested layout** and to `false` only for a
  plain `Item`. Left alone, one row takes the whole column and everything below it is laid
  out one pixel high, which reads as a rendering fault rather than a layout one.

## Sizes come from Theme

`Theme` carries the type scale — `fontLabel`, `fontBody`, `fontReading`, `fontHero` — and
every size in the scene is one of them. The panel is read from two to three metres, which is
the whole reason: a literal pixel size written while looking at a desktop window is always
too small, and nothing on screen says so.

## The status detail needs a width

`StatusBadge`'s text elides, and elide needs a width. `Card` gives it whatever its title
leaves through `maximumWidth`; unbounded, a connection error prints straight across the
card's own title, which is the one line saying which panel it is. The narrow card on the
camera screen also passes `status` without `statusDetail`, because what fits there is not
worth reading.

## A button has no size of its own

`Button` sets implicit sizes and never `width`/`height`: the panels put their controls in a
layout and let it stretch them across the card, and a button that assigns its own size never
fills the box it was given. `SegmentedBar` is the same control for a set of commands that
belong together - the gate's Open/Stop/Close - drawn as one bar, with only the two outer
corners rounded and each section squared off against its neighbour.

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

`fixedLow`/`fixedHigh` take the vertical range away from the data - the precipitation chart
is pinned to 0-100% and the tank to its 20-65 degrees, the same bounds its gauge carries. A
percentage that rescales itself puts 40% at the top of the frame, which reads as a downpour
from any distance at which the axis label cannot be read. A fixed range does not change what
`hasVisible` means: the point count is still taken over the window, so an empty window still
draws `no data` rather than an empty frame with axes.

## The chart's window is what the forecast spans animate

`windowStart`/`windowEnd` left at zero means "the whole series", which is what the hot water
history wants. The weather panel drives them instead, and animating `windowEnd` is the whole
of the compression between the three forecast contexts - see [contexts](docs/contexts.md).

**The vertical range follows the window, not the series.** A day scaled against a week's
extremes is a line that barely moves. Because the range is recomputed as the window animates,
it eases with it rather than stepping when the transition lands.

A window containing fewer than two points draws `no data`, not an empty frame with axes: a
range past the end of the forecast must not look like a range with nothing happening in it.

The day/night bands come from `Weather.daylight` and are mapped through the same window as
the line, so the two cannot disagree. A query that did not ask for the daily block yields no
bands and no warning, exactly as [rest](docs/rest.md) describes for every other field.

The axis label format follows the width of the window. Fixed at `HH:mm`, a week reads as a
day; fixed at the weekday, a week reads as the same weekday twice.

## The clock ticks off a timer

`Date()` is not a property, so a binding on it is evaluated once and never again — a clock
frozen at startup, with no error anywhere. The `Timer` in `Clock.qml` is what moves it.
