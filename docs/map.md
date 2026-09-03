# The map context, and where its positions come from

> Owns: src/qml/MapScreen.qml
> Owns: src/qml/MapPanel.qml
> Owns: src/app/People.hpp
> Owns: src/app/People.cpp
> Owns: src/app/PeopleModel.hpp
> Owns: src/app/PeopleModel.cpp
> Owns: src/integrations/Location.hpp
> Owns: src/integrations/Location.cpp
> See:  docs/contexts.md docs/integrations.md docs/state.md docs/packaging.md docs/rest.md docs/location.md docs/tiles.md docs/input.md

One screen showing everyone who shares a location, framed so all of them fit with a tenth of
the span to spare. `Location` fetches, `PeopleModel` holds the rows, `People` is what QML binds
to, `MapPanel` draws.

## The scrape is not here, and must not be

Location sharing has no official Google API. What reads it instead is a supervising daemon
holding a credential that is full account access — [location](docs/location.md).

So it runs on the house network, `people-url` points at it and `map-tile-url` is the same host on a
different path. **A change that starts logging into Google from this process is a change in
the wrong repository.**

The contract, which is the whole coupling:

```json
{"people":[{"id":"…","name":"Ala","lat":…,"lon":…,
            "accuracy_m":25,"seen_at":1756100000,"battery":73}]}
```

`seen_at` is epoch **seconds**, like everything in `Sinks.hpp`, and it is Google's own stamp
on the fix rather than the time the service polled — a marker's age is how old the *position*
is. `PeopleModel` is where it becomes the milliseconds QML wants. `battery` may be absent and
arrives as `-1`, out of range on purpose: a phone at 0% and a phone that did not say are
different facts.

`id` is load-bearing. `PeopleModel::set` matches incoming rows against it, so a stable id is a
marker that moves and an unstable one is every marker on screen destroyed and rebuilt.

## Why this is the only QAbstractListModel in the repository

A `Repeater` over a `QVariantList` — how every other list here is drawn — destroys and
re-incubates **every** delegate when any value in it changes; `src/qml/LineChart.qml` says so
at the point that caused it. A map delegate is a `MapQuickItem`, so one person moving would
tear down every marker. `set()` therefore removes absent ids, appends new ones, and emits
`dataChanged` for only the roles that moved. Rows are never reordered.

Coordinates cross the seam as plain doubles rather than as `QGeoCoordinate`, which keeps
`Qt6::Positioning` off the link line and out of `Build-Depends` — the delegate calls
`QtPositioning.coordinate()` itself. Adding a geo type to `src/app/` puts it back.

## What is silent here

**`activeMapType` must be the `CustomMap` entry.** The osm plugin only reaches
`osm.mapping.custom.host` through that map type. Left on anything else it draws Qt's own
hardcoded providers: tiles arrive, the map works, and they are not the configured ones.

**`osm.mapping.providersrepository.disabled` must stay true.** Enabled, the plugin fetches
provider metadata from `maps-redirect.qt.io` at startup — an internet dependency at boot that
nothing in `debian/control` declares.

**`map-tile-url` must end in a slash.** The plugin appends `%z/%x/%y.png` to it with no
separator of its own, so a host written without one asks for `https://host8/83/138.png` — the
zoom level welded onto the host name. It reports itself as a DNS failure, which sends you
looking at the network rather than at the setting. [tiles](docs/tiles.md) is the other end.

**A tile that fails to arrive is a hole for good** — the plugin gives up after five tries and
never asks again; [tiles](docs/tiles.md) is what it leaves in the log. `refresh`
([input](docs/input.md)) is the way back, and only on this context: `Map.clearData()` drops the
tile cache and re-asks for the visible screen, so **the map blanks and redraws**, good tiles
included. It also calls `People.refresh()`, whose sink `main()` sets once `Integrations` exists
— [state](docs/state.md).

**`activeMapType` is assigned, never bound.** The plugin fills `supportedMapTypes` only once
its provider has answered; a binding written against it can evaluate against an empty list,
and it evaluates once. `MapPanel` sets it from `onSupportedMapTypesChanged`, matching on
`MapType.CustomMap` by style and not by position in the list. No fall-back to another type: a
map quietly drawing somebody else's tiles is the failure being guarded, so it says so.

**Empty bounds are a real place.** `People.hasBounds` is false when nobody is sharing, and the
viewport is then left alone. Four zeroes is a coordinate in the Gulf of Guinea; a map framed
on empty bounds is not blank, it is confidently wrong.

**Two people at one address draw two boxes on the same pixels.** `PeopleModel::restack` numbers
everyone within `kSamePlaceDegrees` of each other 0, 1, 2, and the delegate lifts each label that
many boxes clear of the one below. Only the labels move; the dots coincide because the people do.
The step is the box's own measured height, so **it holds only while every box is the same
height** — hide the marker's detail line for fresh fixes and these stack back on top of each
other with nothing to report it.

**One person has no bounding box.** So does a household at one address: zero span asks the map
for infinite zoom. `MapPanel.minimumSpan` floors it at 0.01 degrees, and the padding is
applied to the floored span rather than to the raw one.

**A stale fix looks exactly like a fresh one, so every marker says how old it is.** Nothing
drops a person for being old — somebody vanishing off this map has to mean they stopped
sharing and not that their phone slept — so the age is always drawn, and past
`MapPanel.staleAfterMs` the marker turns amber rather than disappearing. It is measured against
`MapPanel.now`, resampled by a one-minute `Timer` while the panel is on screen: `seenAt` never
moves, so “12 min temu” written once is wrong a minute later with nothing to say so.

**Three runtime dependencies nothing can see, and they fail in two different ways.**
`qml6-module-qtlocation` and `qml6-module-qtpositioning` are QML imports, so `dh_shlibdeps`
finds neither — [packaging](docs/packaging.md). A missing one does not cost one context:
`MapScreen` is instantiated by `Main.qml`, so the unresolved import fails the root object and
`main.cpp` turns it into `exit(1)`. The board restart-loops on a blank screen, and the five
contexts with nothing to do with the map never draw.

**`qt6-location-plugins` is the third, and it says nothing at all.** The QML module ships only
the import; the `osm` back end is a separate package. Without it `Plugin { name: "osm" }`
resolves to no provider, `supportedMapTypes` stays **empty forever** — the signal never fires —
and `activeMapType` is assigned `undefined`. The scene loads, all six contexts cycle, the
markers are drawn, and there are simply no tiles under them. One `QGeoMapType` warning at
startup is the whole evidence.

## The screen

`map` is on `Nav.cycle` and costs what every id costs — a `State` on every element of every
other screen, and an arm in `Carousel.cardOf()` whose fall-through would otherwise park the
map's frame on the cameras slot. [contexts](docs/contexts.md) is where that machinery lives.

`Map` and not `MapView`: an item that takes focus starves the single `Keys.onPressed` in
`Main.qml` — [input](docs/input.md) — and the board has no pointer to drive a drag handler.

The tenth is `MapPanel.fitPadding`; `People` publishes the raw extent. `visibleRegion` is
assigned from `boundsChanged` and not bound, because a binding that leaves the viewport alone
when there is nobody has to name `visibleRegion` on its own right-hand side.
