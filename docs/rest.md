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

**open-meteo answers 200 with the fields it was asked for and omits the rest.** A typo in the
query string is therefore a valid response with a missing key, not an error — the panel that
wanted it simply stays empty. Dropping a field from `rest-url` silently removes a chart.

Its timestamps carry no zone and the query asks for none, so they are UTC and are parsed
with `timegm`. `mktime` would read them as local time and slide the whole forecast by this
machine's offset: a chart that looks entirely plausible and is drawn hours from where it
belongs. **A `timezone` parameter must never be added to `rest-url`** - it makes open-meteo
answer in local time in the same zone-less format, which slides everything by the same
invisible amount from the other direction.

`forecast_days=8` and not 7: the scene's window starts at *now* and runs forward, so a
seven-day span needs an eighth day to reach into. Shortened, the last hours of the widest
context are simply empty.

The `daily` block is read for `sunrise` and `sunset`, one pair per day, and becomes the
charts' day/night bands. A day where either end is null - which is how open-meteo reports a
sun that does not set - is dropped whole, because half a band is a band that ends in 1970.


