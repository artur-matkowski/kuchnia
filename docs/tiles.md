# The map's tiles

> Owns: services/app/tiles.py
> See:  docs/map.md docs/whereabouts.md docs/location.md docs/input.md

The board reaches one host for the map and not two: `/tiles/{z}/{x}/{y}.png` proxies
`tile_upstream` and keeps what it fetched. The panel's osm plugin appends `{z}/{x}/{y}.png` to
`map-tile-url` with no separator of its own, so that setting **ends in a slash**, and it and
this prefix are one fact written in two repositories — [whereabouts](docs/whereabouts.md) has
what a missing slash does.

The identifying `User-Agent` is not politeness. The OpenStreetMap tile policy rejects a client
that does not identify itself, and this proxy is the only client that server ever sees: the
panel's own `kuchnia` never reaches it.

## A failed fetch is a hole that outlives the failure

QtLocation asks for a tile, retries it **five times across about twenty seconds**, and then
gives up on it and never asks again — nothing re-requests it when the outage ends. So half a
minute of bad network between the panel and this service leaves permanent holes in a map that
is working perfectly by every other measure, and the map cannot tell anybody, because as far
as it knows it has drawn everything it was given.

The whole evidence is one line per tile, in the **panel's** log and not this service's:

```
QGeoTileRequestManager: Failed to fetch tile (8,137,83) 5 times, giving up. Last error ...
```

It is a `qWarning`, so `routeQtMessages` in `src/main.cpp` puts it at WARN where every other
line goes — `journalctl --user -u kuchnia` on the board. It names the tile and the network
error underneath it, which is what tells a throttled request apart from a name that would not
resolve. `refresh` on the map context — [input](docs/input.md) — is the way back from a hole
already made.

## Why an expired tile beats a 502

`_read_fresh` serves what is inside `tile_ttl_days`; past that the tile is fetched again. When
that fetch **fails**, `_stale` answers with the expired tile, and only an upstream **404**
refuses outright — nothing on disk can stand in for a tile that does not exist.

That is not the fallback beside a broken path that the working agreement forbids. An expired
tile is the real picture rather than a plausible-looking default, the pyramid moves in months,
and the fetch that failed is already a `WARNING` in this service's log. What it replaces is
not a visible failure: it is a hole nobody is told about and nothing repairs.
