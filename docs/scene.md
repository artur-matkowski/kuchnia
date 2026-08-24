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
> Owns: src/qml/ChartCard.qml
> Owns: src/qml/TemperatureCard.qml
> Owns: src/qml/WindCard.qml
> Owns: src/qml/ConditionsCard.qml
> Owns: src/qml/ForecastCard.qml
> Owns: src/qml/RainChanceCard.qml
> See:  docs/state.md docs/media.md docs/radio.md docs/app.md docs/contexts.md docs/carousel.md docs/input.md

The panels the screens are assembled from - the clock, the gauge, the charts, the gate and
the radio - and the frame they all sit in. Which panel is on which screen, and how it gets
there, is [contexts](docs/contexts.md).

`Main.qml` is only the shell: the geometry, the focus and the keyboard. It owns no layout.

`Window` asks the session for the whole screen through `visibility`, and nothing may pin its size
again — a `minimumWidth` equal to a `maximumWidth` is a window the compositor cannot resize, so
the fullscreen request is accepted and does nothing. 1366x768 is the windowed size only.

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
every size in the scene is one of them. A literal pixel size written while looking at a
desktop window is too small on a panel read from two to three metres, and nothing says so.

## The status detail needs a width

`StatusBadge`'s text elides, and elide needs a width. `Card` gives it whatever its title
leaves through `maximumWidth`; unbounded, a connection error prints straight across the
card's own title, which is the one line saying which panel it is.

## A button has no size of its own

`Button` sets implicit sizes and never `width`/`height`: the panels put their controls in a
layout and let it stretch them across the card, and a button that assigns its own size never
fills the box it was given. `SegmentedBar` is the same control for a set of commands that
belong together - the gate's Open/Stop/Close - drawn as one bar.

Both take their **height** from the type scale and not from what the card has left over. A
`Layout.fillHeight` on either hands it every pixel the readings above it did not use, which
is most of the panel and reads as a control built for a different screen.

## Card has no default property

A `default property alias content: body.data` is the obvious way to write a frame, and it is
wrong here: the default property applies where a component is *defined* as well as where it
is used, so `Card`'s own title and badge land in the inner item — including the inner item
itself. Panels anchor below `contentTop` instead.

## Charts draw nothing when they have nothing

`LineChart` renders `no data` for an empty or single-point series, and must never fall back
to a flat line at zero: that is indistinguishable from a real reading.

`_plot()` reads `plot.width`/`plot.height` instead of taking them as arguments, and that is
what re-evaluates the `PathPolyline` binding on a resize — QML records every property read
during an evaluation, called functions included. Passed in, the line draws once and no more.

**`_range()` and `_plot()` run on every frame of a span change, on every visible chart, so
neither may touch `series.points`.** It is a `QVariantList` of `QPointF` and every element
read through it materialises a value-type wrapper; `_flat` copies the series into two arrays
of plain numbers once per change, and the loops read those. **Both also require x to ascend**
— the archive orders by its bucket and a forecast is zipped against `hourly.time` — because
they binary-search the window rather than scanning. A series that stopped ascending would be
drawn truncated at the first step backwards, with nothing anywhere saying so.

The grid is gated on `hasVisible` for the same reason the axes are: a full grid with no line
in it is the "empty frame" that `no data` exists to prevent.

**Neither grid may be a `Repeater` over a list.** A `Repeater` handed a new model tears down
every delegate and builds a fresh set, on the GUI thread, inside the binding that moved it -
a grid that follows the range stops the panel. `_levels()` and `_days()` answer a count and a
delegate works out its own value from `index`, because a count holds still while values move.

`minimumSpan` opens the vertical range when the data is nearly flat, so a tank holding steady
is a steady line and not sensor noise magnified. `fixedLow`/`fixedHigh` take the range away
from the data altogether, and neither changes what `hasVisible` means: the point count is
still taken over the window, so an empty window draws `no data` and not an empty frame.

## The chart's window is what the forecast spans animate

`window` left at `0,0` means "the whole series", which is what the hot water history wants.
The weather panel drives it instead, and animating `y` is the whole of the compression
between the forecast spans - see [contexts](docs/contexts.md).

**It is one property because two would be assigned one after the other.** A chart that has
never been visible has no window at all, so the evaluation between the first assignment and
the second sees an end and no start - a window running from the epoch, whose day grid is
twenty thousand `Rectangle`s built on the GUI thread. That was four and a half seconds on the
first menu press, from `CarouselWeather`'s copies, and it is why `ForecastSpan` publishes a
point rather than two reals.

**A `ChartCard` follows the window only while it can be seen.** An invisible item stops
rendering but not evaluating, and four of the six charts are off screen at any moment - the
two on whichever forecast screen is not showing, and the carousel's two copies. `visible` is
effective visibility, so the `Binding` releases when the card's `SceneElement` fades out and
is back on the frame opacity first rises, before the card has been drawn.

**The vertical range follows the window, not the series.** A day scaled against a week's
extremes is a line that barely moves. Because the range is recomputed as the window animates,
it eases with it rather than stepping when the transition lands.

The day/night bands come from `Weather.daylight` and are mapped through the same window as
the line, so the two cannot disagree. A query that did not ask for the daily block yields no
bands and no warning, exactly as [rest](docs/rest.md) describes for every other field.

The axis label format follows the width of the window. Fixed at `HH:mm`, a week reads as a
day; fixed at the weekday, a week reads as the same weekday twice.

## The clock ticks off a timer

`Date()` is not a property, so a binding on it is evaluated once and never again — a clock
frozen at startup, with no error anywhere. The `Timer` in `Clock.qml` is what moves it.
