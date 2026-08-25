# The charts

> Owns: src/qml/LineChart.qml
> Owns: src/qml/ChartCard.qml
> See:  docs/scene.md docs/state.md docs/contexts.md docs/rest.md docs/diagnostics.md

One line drawn from a `ChartSeries`, and the card that holds one of the forecast's. The series
arrives in data space and is mapped to pixels here - see [state](docs/state.md). The type scale
and the boxes cut to hold it are [scene](docs/scene.md).

## Charts draw nothing when they have nothing

`LineChart` renders `brak danych` for an empty or single-point series, and must never fall back
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
in it is the "empty frame" that `brak danych` exists to prevent.

**Neither grid may be a `Repeater` over a list.** A `Repeater` handed a new model tears down
every delegate and builds a fresh set, on the GUI thread, inside the binding that moved it -
a grid that follows the range stops the panel. `_levels()` and `_days()` answer a count and a
delegate works out its own value from `index`, because a count holds still while values move.

`minimumSpan` opens the vertical range when the data is nearly flat, so a tank holding steady
is a steady line and not sensor noise magnified. `fixedLow`/`fixedHigh` take the range away
from the data altogether, and neither changes what `hasVisible` means: the point count is
still taken over the window, so an empty window draws `brak danych` and not an empty frame.

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

**The range labels are `Theme.fontBody`, and three expressions have to say so.** They are the
chart's range and not a caption, so they are read at body size; `_gutter` is that size times a
character count, and the axis strip's height is that size plus a rule. Move the labels alone and
the widest of them runs out of the gutter, so the line starts under its own axis. Raising the
size is also how a chart is made to give room back: the plot is whatever the gutter and the
strip leave.

The axis label format follows the width of the window. Fixed at `HH:mm`, a week reads as a
day; fixed at the weekday, a week reads as the same weekday twice.
