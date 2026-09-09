# The map panel: the plugin, the viewport and the roster list

> Owns: src/qml/MapPanel.qml
> See:  docs/map.md docs/tiles.md docs/input.md docs/settings.md docs/contexts.md docs/packaging.md

One `Map`, a marker per person, and a list down the right-hand side that picks one of them to
follow. Where the positions come from is [map](docs/map.md); this is what is done with them.

## Four things the plugin must be told, and all four fail silently

Every one of these leaves a map that looks like it is working.

**`map-tile-url` must end in a slash.** The plugin appends `%z/%x/%y.png` to it with no
separator of its own, so a host written without one asks for `https://host8/83/138.png` — the
zoom level welded onto the host name. It reports itself as a DNS failure, which sends you
looking at the network rather than at the setting. [tiles](docs/tiles.md) is the other end.

**`activeMapType` must be the `CustomMap` entry, and must be assigned rather than bound.** The
plugin reaches `osm.mapping.custom.host` through that map type alone — left on anything else it
draws Qt's own hardcoded providers, so tiles arrive, the map works, and they are not the
configured ones. It fills `supportedMapTypes` only once its provider has answered, and a binding
against that list can evaluate against an empty one, once. So it is set from
`onSupportedMapTypesChanged`, matched by style and not by position, and falls back to no other
type: a map quietly drawing somebody else's tiles is the failure being guarded.

**`osm.mapping.providersrepository.disabled` must stay true.** Enabled, the plugin fetches
provider metadata from `maps-redirect.qt.io` at startup — an internet dependency at boot that
nothing in `debian/control` declares.

**`qt6-location-plugins` says nothing at all when it is missing.** `qml6-module-qtlocation`
ships only the import; the `osm` back end is a separate package — [packaging](docs/packaging.md).
Without it `Plugin { name: "osm" }` resolves to no provider, `supportedMapTypes` stays **empty
forever** — the signal never fires — and `activeMapType` is assigned `undefined`. The scene
loads, all five contexts cycle, the markers are drawn, and there are simply no tiles under them.
One `QGeoMapType` warning at startup is the whole evidence.

## What the viewport remembers, and what a poll may not take back

`People::update` emits `boundsChanged` on **every** poll, so `frame()` runs every
`people-interval-ms`. It is the only place the viewport is decided, and everything it must not
undo is tested inside it.

**`zoomed` is what makes a zoom key work twice.** Without it `frame()` rewrites the zoom within
one interval; while it is set the poll moves the centre and leaves the zoom alone. Picking
another person clears it. `refresh` does not: that key is the tiles and the roster, not where
the map is looking.

**`Behavior on center` holds a `CoordinateAnimation`**, because a coordinate is not a number and
a `NumberAnimation` on one snaps with nothing said anywhere. Both Behaviors are off until
something has been framed, or the first fix arrives as a sweep from 0,0 and from whatever zoom
the plugin starts at.

**`zoomTarget` is what makes the zoom safe to ease.** `map.zoomLevel` read back mid-ease is
wherever the animation has reached, so a key that added to *it* would give less than three levels
for three quick presses. The target accumulates and the map follows it — and it is clamped
against the plugin's `minimumZoomLevel`/`maximumZoomLevel`, because Qt clamps the *level* but not
the target: ten presses past the maximum are otherwise ten presses of nothing on the way back.

**`followZoom` is a zoom level where `minimumSpan` is a span**: a span reaches the map only
through `visibleRegion`, one assignment moving centre and zoom together, which cannot be eased.
Writing `center` over a `visibleRegion` already assigned is safe only because nothing here
resizes — `whereabouts.box` is a fixed cell — so a map that started changing size would have to
clear it.

**Empty bounds are a real place.** `People.hasBounds` is false when nobody is sharing, and the
viewport is then left alone. Four zeroes is a coordinate in the Gulf of Guinea; a map framed on
empty bounds is not blank, it is confidently wrong.

**One person has no bounding box.** So does a household at one address: zero span asks the map
for infinite zoom. `minimumSpan` floors it at 0.01 degrees, and `fitPadding`'s tenth is applied
to the floored span rather than to the raw one. `visibleRegion` is assigned from `boundsChanged`
and not bound, because a binding that leaves the viewport alone when there is nobody has to name
`visibleRegion` on its own right-hand side.

## The tiles ahead of the viewer

`prefetchData()` is the **only** prefetch hook QtLocation gives QML, and nothing else in this
scene calls it — in QtLocation the gesture area drives it, and this map has neither gestures nor
a pointer. Both Behaviors call it when they settle.

**`onFinished` and not `onStopped`.** A `Behavior` retargeted mid-flight *stops* its animation
rather than finishing it, so a fast walk down the list prefetches once, when the motion settles,
instead of once per key press.

**Which layer it warms is Qt's own heuristic.** `setPrefetchStyle`, which would ask for both
neighbours, is private API and not on the QML type — so a zoom step that still arrives cold is
that heuristic warming the layer being left, to be reported rather than worked around with a C++
subclass linked against private symbols. The fetch itself costs one warm request against the
tile proxy ([tiles](docs/tiles.md)), and a whole extra layer of real ones against a public
server ([demo](docs/demo.md)).

## The list

**Its `Wszyscy` row is not a row of the model,** so it is drawn above the view and not as its
header, where a long roster would scroll the only way back out of reach. The walk wraps through
it in both directions, which is why there is no separate key for framing everybody again.

**It must not take focus, must not be interactive, and must be clipped.** Focus starves the
single `Keys.onPressed` in `Main.qml` — the reason this is a `Map` and not a `MapView`; a flick
has no pointer to make it and could only leave the list where nothing put it; and the carousel
scales this screen into a miniature, where a shut list outside the card is drawn across the
card beside it.

The five keys that drive it are announced by `Actions` on the map context and nowhere else,
which is why the one handler here switches on the id and tests nothing more —
[input](docs/input.md).

## The markers

**Two people at one address draw two boxes on the same pixels.** `PeopleModel::restack` numbers
everyone within `kSamePlaceDegrees` of each other 0, 1, 2, and the delegate lifts each label
that many boxes clear of the one below. Only the labels move; the dots coincide because the
people do. The step is the box's own measured height, so **it holds only while every box is the
same height** — hide the detail line for fresh fixes and these stack back on top of each other
with nothing to report it.

**A stale fix looks exactly like a fresh one, so every marker says how old it is.** Nothing
drops a person for being old — somebody vanishing off this map has to mean they stopped sharing
and not that their phone slept — so the age is always drawn, and past `staleAfterMs` the marker
turns amber rather than disappearing. It is measured against `now`, resampled by a one-minute
`Timer` while the panel is on screen: `seenAt` never moves, so “12 min temu” written once is
wrong a minute later with nothing to say so.
