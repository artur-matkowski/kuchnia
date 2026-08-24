# Diagnostics

> Owns: src/app/Trace.hpp
> Owns: src/app/Trace.cpp
> Owns: scripts/collect-freeze.sh
> See:  docs/app.md docs/integrations.md docs/contexts.md docs/media.md docs/scene.md

Where the GUI thread was when it stopped answering. Input is on that thread and Qt's threaded
render loop blocks it on the render thread every frame, so a freeze in either reads the same
from outside — the panel stops taking keys. This is what tells the two apart.

## The watchdog reports while the thread is still blocked

That is the whole reason it is not a timer. A timer lives on the thread it is measuring: it
cannot fire until that thread is running again, it can only say how late it was, and a process
killed during the freeze leaves nothing at all.

Instead a `QTimer` writes a timestamp every 50 ms and a plain thread watches it. Silence past
250 ms is a block, and the line names the innermost open span:

```
the gui thread has been blocked for 1400 ms, inside 'nav.current.carousel' (open 1390 ms)
the gui thread has been blocked for 2600 ms, with no span open - the block is outside the
    instrumented path: render sync, event delivery, or C++ under a binding
```

Those two are the first bisection. *Inside a span* is our code and the span names it; *no span
open* is Qt's, and the frame timings beside it say which phase.

**The span stack is kept whatever the log level says.** Only the per-span lines are gated on
`Trace.enabled`. Make `begin()` return early when logging is off and a board running at the
default level reports every freeze as "no span open" — the watchdog goes blind and nothing
says so.

**`watch()` runs after the settings and after `QGuiApplication`.** Before the settings,
`enabled` answers for a level that was never applied; before the application object, the
heartbeat is a `QTimer` with no event dispatcher to fire in.

## Spans

`Trace.begin(tag)` / `Trace.end(tag)` pair on the exact string, and a mismatch is reported
rather than guessed at — a pop that guessed would corrupt every duration above it. Wrap a body
with `try`/`finally` wherever a branch returns out of the middle of it, which is most of them.

`Trace.enabled` is **CONSTANT**, and it must stay that way: `LineChart`'s three functions read
it inside bindings, and a `NOTIFY`able property read during an evaluation becomes a dependency
of that binding.

Those three are the only guarded call sites. Everything else — the key handler, the action, the
context assignment, a camera's `source` — happens once per key press, and a call that cheap is
not worth a condition. The charts run on every frame of a span change, on every visible chart.

Two marks are not spans and are worth knowing about: `CardFrame` and `SceneElement` each
name themselves when their state changes. A context assignment applies six frames and
eighteen elements one after another and reports nothing about the order or the cost, so the
gaps between those marks are the only view of the cascade there is. It is how the four and a
half seconds on the first menu press turned out to be three of the eighteen.

**The log line is written inline, on the thread being measured.** A span under a tenth of a
millisecond is mostly the cost of saying so, and a capture with `PERF` at debug is not a
measurement of the panel at rest.

The tags are what `scripts/collect-freeze.sh` greps for. They carry no spaces — a report reads
them as fields — and a camera's is built from its label, so renaming a tile renames its spans.

## Capturing one

```sh
scripts/build.sh host
scripts/collect-freeze.sh
```

It does not build: a binary older than `src/` is refused, because a capture of the wrong code
reads exactly like a capture of the right one.

**Press the menu key three times**, opening a card between presses. Three is the measurement,
not politeness: a cost paid only on the first press is the scene graph being built for screens
that were never visible; a cost paid on all three is the state machine, a stream being opened,
or a binding that runs per frame.

The report writes a row per press — what the action cost, what the watchdog saw, and the worst
`sync=`/`render=` of any frame in the three seconds after it — then the raw timeline of each.

**The frame timings need two things and give nothing if either is missing.** Qt prints them
only for `qt.scenegraph.time.*` categories that are switched on, and they arrive as debug
messages under the `QT` topic, which is at info by default. The collector sets both; a report
that says no frames were timed is a broken capture and not a finding. Everything else in it
still reads.

`--bin`, `--config` and `--out` are what run it against the board's installed binary over ssh,
with the unit stopped so the two are not fighting over the screen.
