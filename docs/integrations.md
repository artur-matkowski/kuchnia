# The integrations

> Owns: src/integrations/Log.hpp
> Owns: src/integrations/Log.cpp
> Owns: src/integrations/Settings.hpp
> Owns: src/integrations/Settings.cpp
> Owns: src/integrations/Service.hpp
> Owns: src/integrations/Service.cpp
> Owns: src/integrations/Integrations.hpp
> Owns: src/integrations/Integrations.cpp
> See:  docs/app.md docs/state.md docs/database.md docs/rest.md docs/mqtt.md docs/packaging.md docs/input.md

Three clients of things on the LAN — PostgreSQL through libpqxx, HTTP through Poco, MQTT
through paho — each on its own thread, each configured by `Settings` and each reporting
through `applog`.

**Nothing here may touch Qt.** What the scene reads leaves through the plain callbacks in
`Sinks.hpp`; getting onto the GUI thread is the receiver's problem, and
[state](docs/state.md) is where that happens — once, for all of them.

The two internal modules under `deps/` are submodules built from source. They are ordinary
git submodules of this repository, so a fresh checkout needs
`git submodule update --init --recursive` or `CMakeLists.txt` stops with that instruction.

## The logger drops everything until it is told where to write

`debug::log` holds a **null** output buffer until `SetOutput()` is called, and silently
discards every line written before that — including its own complaints. `applog::init()` is
therefore the first statement in `main()`, ahead of reading the settings, because reading
them logs.

**And it writes into `cout`'s buffer without ever flushing it.** A stdout that is not a
terminal is fully buffered, which is how the board runs this — the unit's is a pipe into the
journal. Without the `setvbuf` line-buffering call in `init()` the log stays empty until 4K
accumulates, and a process killed rather than returning from `main` loses all of it. That is
every case worth reading a log for.

Its stream flushes on `'\n'` and on nothing else, and hands out **one shared buffer per
(level, topic)**. Writing to it directly makes a forgotten newline a line that never appears
and two threads a line that interleaves — both silent. `applog::Line` exists so neither is
possible: it assembles the text, then emits it terminated and under a lock in its
destructor. Use the `LOG_*` macros, or construct a `Line` directly when a loop has to build
one line across several statements. It is also what puts the wall clock time on the line —
the logger writes none, and a log with no times in it cannot answer how long a gap was.

`applog::stream()` hands out the raw stream for a library that logs into a `std::ostream`.
It bypasses the lock, so it suits only a library that logs from one thread —
`Module-cpp-config` qualifies, being finished before any service starts.

An unregistered topic makes the logger complain to `cerr` **per line**. Topics live in
`kTopics` in `Log.cpp` and in the constants atop `Log.hpp`; adding one means both. `QT` is
one of them and is written to only by the message handler `main.cpp` installs — see
[app](docs/app.md); `PERF` is the other, and is [diagnostics](docs/diagnostics.md).

`log-level` raises every topic, or every topic and then some of them by name —
`info,QT=debug,PERF=debug`. **The fields are applied in the order they are written**, so a
bare level after a topic's own quietly wipes it.

## Two headers that pollute the global namespace

`Logger.hpp` defines `ERROR`, `WARNING`, `INFO` and `ALL` as object-like macros, and
`Config.hpp` puts `INT`, `FLOAT`, `STRING`, `BOOL` and `FLAG` in the global namespace as
bare enumerators. Both are contained rather than worked around:

* `Log.hpp` `#undef`s the four macros after including `Logger.hpp`, so nothing downstream
  sees them. Delete those `#undef`s and an unrelated file with an `ERROR` enumerator stops
  compiling, naming its own line.
* `Config.hpp` is included by `Settings.cpp` and by nothing else. `Settings.hpp` exposes a
  plain struct so the enumerators never reach another translation unit.

## What the settings will not tell you

Priority is argv, then environment, then the config file, then the default in `specs()`.
The environment name is derived from the parameter name — uppercased, `-` to `_`, so
`mqtt-password` is `MQTT_PASSWORD`. Renaming a parameter silently renames its environment
variable and orphans whatever was exporting the old one.

* **An unknown `--parameter` on the command line is skipped without a word.** A typo in an
  argument changes nothing and reports nothing.
* **A `BOOL` is `true` and nothing else**, and an empty value is the same as no line at all:
  the parser compares to that string exactly, so `fullscreen:True` is false and `mqtt-user:`
  leaves the compiled-in default in place, neither of them saying a word. `FLAG` is a different type with a
  hardwired `false` default that no config line can turn on — which is why `fullscreen`,
  needing to default on, is a `BOOL` and `gate-control` is not.
* **A non-numeric value where an `INT` is expected throws**, from any of the three sources.
  `loadSettings()` catches it and names the failure; without that catch it is a `terminate()`
  during startup that says nothing about which parameter was wrong.
* **A missing config file is not an error** — the module writes a default one and carries on,
  with a bare `ofstream`: no parent directory is made, and a write that fails says nothing.
  `loadSettings()` creates `~/.config/kuchnia` first and refuses to start when it cannot, then
  sets `0600` on a file that appeared across the call, which the umask would not —
  [packaging](docs/packaging.md). It reads `--configpath` for itself too, to know whether that
  per-user path is in use; the module parses the same flag again and only its copy picks the
  file.
* `Config::Get` with a name absent from `specs()` returns false and leaves the output
  untouched; `Settings.cpp`'s `get()` helper turns that into an error line rather than a
  value that silently stays default.

## Failure is a retry, never an exit

`Service` owns the pattern: a thread, a `step()`, and anything thrown caught, logged and
retried with the delay doubled to `retry-max-ms`. The screen is the point of the program, so
no unreachable service may take the process down — and equally, nothing may paper over a
failure by substituting a plausible value.

Two consequences worth knowing:

* A derived class must call `stop()` in **its own** destructor. `~Service()` also calls it,
  but by then the derived vtable is gone and the thread is still calling `step()`.
* `reset()` runs after a failed step. `Database` and `Mqtt` drop their connection there; a
  connection kept across a failure is one that reports the same error forever.
* `wake()` cuts a `waitFor()` short from any thread, and a wake with nobody waiting is
  remembered rather than lost — which is what stops a library callback from having to do
  blocking work on its own thread. It is also how the scene reaches a worker at all: a gate
  command onto the broker's thread, and the map's refresh key onto the roster's.
* `setHealthSink()` is written without a lock, on the assumption that no worker thread exists
  yet to read it. Call it before `start()`.

## The database

The archive client is its own node: [database](docs/database.md).

## MQTT

The broker client is its own node: [mqtt](docs/mqtt.md).

## REST

The HTTP client is its own node: [rest](docs/rest.md).
