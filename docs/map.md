# The map context, and where its positions come from

> Owns: src/qml/MapScreen.qml
> Owns: src/app/People.hpp
> Owns: src/app/People.cpp
> Owns: src/app/PeopleModel.hpp
> Owns: src/app/PeopleModel.cpp
> Owns: src/integrations/Location.hpp
> Owns: src/integrations/Location.cpp
> See:  docs/whereabouts.md docs/contexts.md docs/integrations.md docs/state.md docs/packaging.md docs/rest.md docs/location.md docs/tiles.md docs/input.md

One screen showing everyone who shares a location. `Location` fetches, `PeopleModel` holds the
rows, `People` is what QML binds to, and `MapPanel` draws — what it does with them, from the
plugin it needs to the person it can be told to follow, is [whereabouts](docs/whereabouts.md).

## The scrape is not here, and must not be

Location sharing has no official Google API. What reads it instead is a supervising daemon
holding a credential that is full account access — [location](docs/location.md) — so it runs on
the house network, `people-url` points at it and `map-tile-url` is the same host on a different
path. **A change that starts logging into Google from this process is a change in the wrong
repository.**

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
`QtPositioning.coordinate()` itself, and `person()` answers doubles for the same reason.
Adding a geo type to `src/app/` puts it back.

## The three the roster list asks for

`idAt`, `rowOf` and `person` exist because the list walks a **row index** and the viewport
follows an **id**, and the two are not interchangeable: a removal shifts every row beneath it,
so an index held across a poll is a different person with nothing to say so.

`person()` answering an **empty map** is the other half of that. It is how somebody who stopped
sharing drops the follow, rather than leaving the viewport parked on a coordinate nobody is at
and tracking a marker that is no longer drawn.

## Two runtime dependencies nothing can see

`qml6-module-qtlocation` and `qml6-module-qtpositioning` are QML imports, so `dh_shlibdeps`
finds neither — [packaging](docs/packaging.md). A missing one does not cost one context:
`MapScreen` is instantiated by `Main.qml`, so the unresolved import fails the root object and
`main.cpp` turns it into `exit(1)`. The board restart-loops on a blank screen, and the four
contexts with nothing to do with the map never draw.

The third, `qt6-location-plugins`, fails the other way round and is
[whereabouts](docs/whereabouts.md).

## The screen

`map` is on `Nav.cycle` and costs what every id costs — a `State` on every element of every
other screen, and an arm in `Carousel.cardOf()` whose fall-through would otherwise park the
map's frame on the cameras slot. [contexts](docs/contexts.md) is where that machinery lives.

One card filling it, because the map is the whole point of the context and a grid of anything
beside it would only take width away from the thing being read from across the room. It is off
the pair of forecast spans and carries no span id of its own.

It answers six keys — `refresh` and the map's own five — and `Actions` announces every one of
them on this context and no other: [input](docs/input.md). `refresh` reaches `Map.clearData()`
and `People.refresh()`, whose sink `main()` sets once `Integrations` exists —
[state](docs/state.md).
