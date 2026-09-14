# The forecast client, and the one HTTP client under it

> Owns: src/integrations/Rest.hpp
> Owns: src/integrations/Rest.cpp
> Owns: src/integrations/Http.hpp
> Owns: src/integrations/Http.cpp
> See:  docs/integrations.md docs/state.md docs/map.md

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

**open-meteo answers 200 with the fields it was asked for and omits the rest.** A typo in the
client's list is therefore a valid response with a missing key, not an error — the panel that
wanted it simply stays empty. Dropping a field there silently removes a chart.

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


