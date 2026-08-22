# The archive client

> Owns: src/integrations/Database.hpp
> Owns: src/integrations/Database.cpp
> See:  docs/integrations.md docs/state.md

A `Service` like the other two — read [integrations](docs/integrations.md) first for the
thread, the backoff and the settings. What is particular to this one is below.

## The queries are in the code, not the config

`Database` runs two statements, both in `Database.cpp` rather than in the config: the code
that reads a result set depends on its column order, and a config string can change one
without the other.

`CWU_temp` is the tank. **Its `value` column is centidegrees** — `4668` is 46.68 °C — which
is the single fact about that schema a reader cannot get from the column names.

The table carries millions of rows and **has no index on `timestamp`**, so the history query
is a sequential scan on every poll. That is why it aggregates in the server: pulling a day of
raw samples across the LAN to average them here would move roughly ten thousand rows to draw
a line a few hundred pixels wide.

The bucket it groups into is **sized from `db-history-hours` rather than fixed**, so widening
the window coarsens the line instead of growing the result set. A minute bucket over a day is
1440 rows for a chart that cannot show them, and every one of them is remapped in QML on each
poll.

An archive that has stopped being written is not an error and libpqxx will not report one.
An empty `CWU_temp` throws here instead, so the panel says "failed" rather than showing a
tank at zero degrees.

## The connection string

libpq's DSN is space-separated `keyword=value`, so a password containing a space silently
ends the value and turns the rest into unrecognised keywords — reported as a connection
error naming a keyword nobody wrote. Every field is quoted for that reason.

`connect_timeout` is not optional either: without it a host that drops packets rather than
refusing them parks the thread in `connect()` indefinitely, and the service looks hung rather
than failed.
