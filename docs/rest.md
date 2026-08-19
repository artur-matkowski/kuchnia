# The HTTP client

> Owns: src/integrations/Rest.hpp
> Owns: src/integrations/Rest.cpp
> See:  docs/integrations.md docs/state.md

A `Service` like the other two — read [integrations](docs/integrations.md) first for the
thread, the backoff and the settings. What is particular to this one is below.

Poco's TLS layer is process-wide and is brought up by `Integrations` before any service and
taken down after all of them. `rest-url` defaults to an https endpoint whose certificate is
verified against the system trust store, so the target needs a CA bundle; the handler
rejects rather than prompts, because an unattended board has nobody to ask.

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

`initializeTls()` and `shutdownTls()` are static and process-wide, called by `Integrations`
around the whole set of services rather than per request.
