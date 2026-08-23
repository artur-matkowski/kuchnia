# The seam

> Owns: src/app/AppState.hpp
> Owns: src/app/AppState.cpp
> Owns: src/app/Panel.hpp
> Owns: src/app/Panel.cpp
> Owns: src/app/Series.hpp
> Owns: src/app/Series.cpp
> Owns: src/app/Gate.hpp
> Owns: src/app/Gate.cpp
> Owns: src/app/HotWater.hpp
> Owns: src/app/HotWater.cpp
> Owns: src/app/Weather.hpp
> Owns: src/app/Weather.cpp
> Owns: src/integrations/Sinks.hpp
> See:  docs/app.md docs/integrations.md docs/scene.md docs/media.md

Everything the scene binds to is a `QObject` under `src/app/`, registered as a QML singleton
under the `Kuchnia` URI. The network clients under `src/integrations/` know nothing about any
of it: they call the plain `std::function`s in `Sinks.hpp`, and `AppState` is where those
become Qt properties.

## The gate says which commands are worth sending

`Gate` exposes `canOpen`, `canClose` and `canStop` beside `state`, and the scene binds the
segments of its control bar to them rather than spelling the signal names again in QML. Each
is a deny-list: a gate that is already opening gains nothing from another `OpenGate`, and a
button that can be pressed to no effect reads as a gate that ignored it. `canStop` is denied
only by the three states in which nothing is moving, so a *stuck* gate — still driving its
motor — can always be stopped.

**An unknown state enables all three.** The empty state before the first retained message,
and any signal the bridge has learned since, are not guessed at. The names live in two
places — here and `mqtt-subscribe` in `Settings.cpp` — and nothing checks that they agree.

## The invariant

**Every sink callback runs on a worker thread, and every one of them does nothing but
`QMetaObject::invokeMethod(..., Qt::QueuedConnection)`.** Nothing else in `src/app/` is ever
touched from another thread.

Setting a `Q_PROPERTY` from a worker thread does not crash and does not warn. It corrupts a
binding somewhere else, minutes later, in a component that has nothing to do with the write.
That is the whole reason this arrangement exists, and it is one lambda away from being
undone: a sink that calls a setter directly compiles, runs, and looks correct.

The payloads are copied into the invocation, so nothing outlives the call.

## Health, and why a panel never guesses

`Panel` is the base of `Gate`, `HotWater` and `Weather`, and carries `status` —
`"connecting"`, `"live"` or `"failed"` — plus the detail text of whatever threw. The scene
renders it on every panel.

A chart that has stopped being updated looks exactly like one that is up to date, and a
gauge parked at zero reads as cold water rather than as no reading. `HotWater.current` keeps
its last value through a failure precisely because zeroing it would be a lie the status
badge is too far away to correct. **Never add a QML-side default that fills in for a panel
that is not `live`.**

`Sinks::health` is one callback for all three services and routes on the `applog` topic. A
service whose topic is not in that `strcmp` chain in `AppState.cpp` is silently never
reported — its panel simply says "connecting" forever.

`Service` reports `Failed` from its catch; each service reports `Live` itself, once it
actually holds data. The base class cannot do the second: `step()` returns only after its
own `waitFor()`, by which point the reading is a whole poll old.

`setHealthSink()` is written without a lock and must therefore be called **before**
`start()`. `Integrations` does that; anything that starts a service earlier has a data race
that will never reproduce under a debugger.

## Series

`ChartSeries` is a `Q_GADGET`, read from QML as one value — `HotWater.history.points`,
`.yMax`. Points stay in data space and `LineChart.qml` maps them to pixels, so a resize
costs a repaint rather than a round trip through C++.

**x is milliseconds, while `Sinks.hpp` carries seconds.** QML's `Date` takes milliseconds;
the multiplication happens in `ChartSeries::from` and nowhere else. Do it twice, or not at
all, and the axis is labelled 1970 — a chart that renders perfectly and is simply wrong.

## Gate commands go out the way they came in

`Gate` holds a command sink, set from `main()` once `Integrations` exists, and its invokables
only queue. The publish happens on the broker client's thread because it waits for a PUBACK;
doing it on the GUI thread freezes the screen for as long as the LAN takes. See
[mqtt](docs/mqtt.md).
