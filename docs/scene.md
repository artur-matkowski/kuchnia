# The scene

> Owns: src/qml/Main.qml
> Owns: src/qml/Theme.qml
> Owns: src/qml/Card.qml
> Owns: src/qml/Button.qml
> Owns: src/qml/SegmentedBar.qml
> Owns: src/qml/StatusBadge.qml
> Owns: src/qml/Clock.qml
> Owns: src/qml/Gauge.qml
> Owns: src/qml/GatePanel.qml
> Owns: src/qml/HotWaterPanel.qml
> Owns: src/qml/TemperatureCard.qml
> Owns: src/qml/WindCard.qml
> Owns: src/qml/ConditionsCard.qml
> Owns: src/qml/ForecastCard.qml
> Owns: src/qml/RainChanceCard.qml
> See:  docs/charts.md docs/state.md docs/media.md docs/radio.md docs/app.md docs/contexts.md docs/carousel.md docs/input.md

The panels the screens are assembled from - the clock, the gauge, the charts, the gate and
the radio - and the frame they all sit in. Which panel is on which screen, and how it gets
there, is [contexts](docs/contexts.md).

`Main.qml` is only the shell: the geometry, the focus and the keyboard. It owns no layout.

`Window` asks the session for the whole screen through `visibility`, and nothing may pin its size
again — a `minimumWidth` equal to a `maximumWidth` is a window the compositor cannot resize, so
the fullscreen request is accepted and does nothing. The windowed size is 1920x1080 because that
is the board's panel and the size the type scale below is measured in: a desktop window is then
the board 1:1, and a screenshot taken from one is worth looking at. A smaller window is not a
preview of anything — the type does not shrink with it.

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
every size in the scene is one of them. They are pixels of the board's 1920x1080 panel, read
from two to three metres: a literal size written while looking at a desktop window is too small
there, and nothing says so.

Three boxes are cut to hold a known number of lines of that type, and each is written out of
the parts rather than as a multiple of one size — the heading does not grow with the reading
under it, so a single multiplier goes wrong the moment the scale moves:

* **`Theme.readingRow`** — a `Card` heading, its margins and one `fontHero` line. Both the
  compact and the weather screen size their top row from it, and the migration between them
  depends on them agreeing.
* **`CompactScreen.gateRow`** — a heading, the gate's state, the read-only line the config can
  turn on, and the command bar.
* **`LineChart`'s gutter and axis strip** — [charts](docs/charts.md).

Nothing clips. A row too short for what is in it draws over the card beneath it, which reads as
two panels fighting rather than as a band that is a few pixels out.

## The status detail needs a width

`StatusBadge`'s text elides, and elide needs a width. `Card` gives it whatever its title
leaves through `maximumWidth`; unbounded, a connection error prints straight across the
card's own title, which is the one line saying which panel it is.

## A button has no size of its own

`Button` sets implicit sizes and never `width`/`height`: the panels put their controls in a
layout and let it stretch them across the card, and a button that assigns its own size never
fills the box it was given. `SegmentedBar` is the same control for a set of commands that
belong together - the gate's Otwórz/Stop/Zamknij - drawn as one bar.

Both take their **height** from the type scale and not from what the card has left over. A
`Layout.fillHeight` on either hands it every pixel the readings above it did not use, which
is most of the panel and reads as a control built for a different screen.

## Card has no default property

A `default property alias content: body.data` is the obvious way to write a frame, and it is
wrong here: the default property applies where a component is *defined* as well as where it
is used, so `Card`'s own title and badge land in the inner item — including the inner item
itself. Panels anchor below `contentTop` instead.

## The charts are their own node

`LineChart` and `ChartCard` are [charts](docs/charts.md): what an empty series draws, why
neither grid may be a `Repeater`, and the window the forecast spans animate.

## The clock ticks off a timer

`Date()` is not a property, so a binding on it is evaluated once and never again — a clock
frozen at startup, with no error anywhere. The `Timer` in `Clock.qml` is what moves it.
