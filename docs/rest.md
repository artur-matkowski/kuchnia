# The forecast client, and the one HTTP client under it

> Owns: src/integrations/Rest.hpp
> Owns: src/integrations/Rest.cpp
> Owns: src/integrations/Http.hpp
> Owns: src/integrations/Http.cpp
> See:  docs/integrations.md docs/state.md docs/map.md docs/charts.md

A `Service` like the other three — read [integrations](docs/integrations.md) first for the
thread, the backoff and the settings. What is particular to this one is below.

`http::` is every HTTP request in the program: `Rest` and
[`Location`](docs/map.md) both go through it, and it exists so that the ten-second timeout,
the certificate policy and the refusal of a scheme that is neither http nor https are each
written once. Two clients that must agree on a timeout are one place for it to drift.

`http::get` takes the name of the config key its URL came from — `rest-url`, `people-url` —
and names it in every exception it throws, so a 404 or a scheme typo reports the line to
edit rather than the URL that line produced.

Poco's TLS layer is process-wide and is brought up by `Integrations` before any service and
taken down after all of them — `http::initializeTls()`, not per request. `rest-url` defaults
to an https endpoint whose certificate is verified against the system trust store, so the
target needs a CA bundle; the handler rejects rather than prompts, because an unattended
board has nobody to ask.

**`rest-url` is the endpoint and the coordinates; the rest of the query is the client's.**
`src/integrations/Rest.cpp` appends every `current`, `hourly` and `daily` field it parses, and
`forecast_days`, beside the code that reads them. A query kept in a config file is one the
application cannot change: the file is written once, from the defaults of whichever version
first started, and no later default reaches it — a new chart would draw `brak danych` on every
board. A `rest-url` naming any of those parameters, or `timezone`, fails the weather panel with
the parameter in the detail instead of being merged: open-meteo unions a repeated parameter, so
a stale list would ride along unnoticed. The fix is deleting everything after the longitude.

**A misspelt field fails every weather panel; a dropped one fails nothing.** open-meteo answers
a name it does not know with a 400, and `http::get` reports the status without open-meteo's
reason, so the detail names no field. A name left out of the list is a valid response without
that key, and the panel that wanted it simply stays empty.

Its timestamps carry no zone and the query asks for none, so they are UTC and are parsed
with `timegm`. `mktime` would read them as local time and slide the whole forecast by this
machine's offset: a chart that looks entirely plausible and is drawn hours from where it
belongs. **A `timezone` parameter is never asked for, and `rest-url` may not carry one** - it
makes open-meteo answer in local time in the same zone-less format, which slides everything by
the same invisible amount from the other direction.

`forecast_days=8` and not 7: the scene's window starts at *now* and runs forward, so a
seven-day span needs an eighth day to reach into. Shortened, the last hours of the widest
context are simply empty.

The `daily` block is read for `sunrise` and `sunset`, one pair per day, and becomes the
charts' day/night bands. A day where either end is null - which is how open-meteo reports a
sun that does not set - is dropped whole, because half a band is a band that ends in 1970.

## The cloud column

`kCloudLevels` feeds both the query and `cloudProfile()`: each level is a `cloud_cover_<P>hPa`
and a `geopotential_height_<P>hPa`, asked for and read from the one table.

**The column is read by index, never through `hourly()`.** That skips nulls, and one level
shortened by a null pairs every later hour with another hour's cover. An hour missing any level
is dropped from every series, and `cloudProfileHours` is the list of hours that were whole: a
stretch without a base is a clear sky inside it and unknown outside it, and it is the only
thing that tells the chart which.

A level at or under the response's `elevation` is below the ground and is skipped. Its cover is
extrapolated, and at the board 1000 hPa sinks under the ground in a low - kept, it draws as fog.

**`kCloudBaseOktas` is one fact in three places**: its order and length are also the legend in
`src/qml/CloudLayersCard.qml` and `Theme.cloudBase` in `src/qml/Theme.qml`. Nothing checks that
they agree, and a threshold without a colour draws white, which reads as overcast.

Cover at a pressure level is open-meteo's estimate from the humidity there, not the model's own
`cloud_cover_low`/`mid`/`high`, so "Warstwy chmur" and "Zachmurzenie" can disagree about the
same hour. That is the data, not a bug to reconcile.
