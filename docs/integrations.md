# The integrations

> Owns: src/integrations/Log.hpp
> Owns: src/integrations/Log.cpp
> Owns: src/integrations/Settings.hpp
> Owns: src/integrations/Settings.cpp
> Owns: src/integrations/Service.hpp
> Owns: src/integrations/Service.cpp
> Owns: src/integrations/Database.hpp
> Owns: src/integrations/Database.cpp
> Owns: src/integrations/Rest.hpp
> Owns: src/integrations/Rest.cpp
> Owns: src/integrations/Mqtt.hpp
> Owns: src/integrations/Mqtt.cpp
> Owns: src/integrations/Integrations.hpp
> Owns: src/integrations/Integrations.cpp
> See:  docs/app.md qt-hmi-buildroot/docs/image-and-flash.md

Three clients of things on the LAN — PostgreSQL through libpqxx, HTTP through Poco, MQTT
through paho — each on its own thread, each configured by `Settings` and each reporting
through `applog`. Nothing in the scene reads any of them; log lines are their whole output.

The two internal modules under `deps/` are submodules built from source. They are ordinary
git submodules of this repository, so a fresh checkout needs
`git submodule update --init --recursive` or `CMakeLists.txt` stops with that instruction.

## The logger drops everything until it is told where to write

`debug::log` holds a **null** output buffer until `SetOutput()` is called, and silently
discards every line written before that — including its own complaints. `applog::init()` is
therefore the first statement in `main()`, ahead of reading the settings, because reading
them logs.

**And it writes into `cout`'s buffer without ever flushing it.** A redirected stdout is
fully buffered, which is exactly how the board runs this — `S99app` appends to
`/var/log/app.log`. Without the `setvbuf` line-buffering call in `init()` the log stays
empty until 4K accumulates, and a process that is killed rather than returning from `main`
loses all of it. That is every case worth reading a log for. Delete that line and the
symptom is an empty log file on a board that is plainly running.

Its stream flushes on `'\n'` and on nothing else, and hands out **one shared buffer per
(level, topic)**. Writing to it directly makes a forgotten newline a line that never appears
and two threads a line that interleaves — both silent. `applog::Line` exists so neither is
possible: it assembles the text, then emits it terminated and under a lock in its
destructor. Use the `LOG_*` macros, or construct a `Line` directly when a loop has to build
one line across several statements.

`applog::stream()` hands out the raw stream for a library that logs into a `std::ostream`.
It bypasses the lock, so it suits only a library that logs from one thread —
`Module-cpp-config` qualifies, being finished before any service starts.

An unregistered topic makes the logger complain to `cerr` **per line**. Topics live in
`kTopics` in `Log.cpp` and in the constants atop `Log.hpp`; adding one means both.

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

* **An unknown `--parameter` on the command line is skipped without a word.** A typo in the
  arguments the init script passes changes nothing and reports nothing. The parameter list
  in `specs()` and the arguments in `qt-hmi-buildroot`'s `S99app` are one fact in two
  repositories.
* **A non-numeric value where an `INT` is expected throws**, from any of the three sources.
  `loadSettings()` catches it and names the failure; without that catch it is a `terminate()`
  during startup that says nothing about which parameter was wrong.
* **A missing config file is not an error** — the module writes a default one at that path
  and carries on. When the path is not writable either, the defaults still apply and only a
  warning says so.
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

## MQTT

**Reconnection is paho's, not `Service`'s.** The client is configured with
`automatic_reconnect`, and the connected handler — which runs on paho's thread, on the first
connect and every reconnect after — is what re-subscribes and re-publishes the retained
status. `Service`'s backoff only covers a connect that never succeeded at all.

**`mqtt-client-id` must be unique on the broker.** Two clients sharing one id disconnect
each other in a loop that reads as a flapping network.

**Nothing under `hc12/tx` may ever be published retained.** The broker persists retained
messages, so a retained `hc12/tx/OpenGate` is replayed to the HC-12 bridge on every restart
of *that* service — the gate then opens by itself, forever, until someone clears the topic
by hand. `publish()` takes the flag explicitly and `sendGateCommand()` passes false.

Gate commands are refused unless `gate-control` is set, and only `OpenGate`, `CloseGate` and
`StopGate` are accepted; the command is published once, after the first connect. MQTT has no
prefix wildcard, so the gate topics are named one by one in `kGateTopics` — a signal added
to `hc12-message-definitions` needs adding there too.

**The desktop and the board build against different paho versions** — 1.5.2 from Debian,
1.3.2 from Buildroot. Only the subset common to both is used, so a host build is not
evidence the board's will compile. Point `CMAKE_PREFIX_PATH` at a locally built 1.3.2 to
check, or build `board`.

## REST

Poco's TLS layer is process-wide and is brought up by `Integrations` before any service and
taken down after all of them. `rest-url` defaults to an https endpoint whose certificate is
verified against the system trust store, so the target needs a CA bundle; the handler
rejects rather than prompts, because an unattended board has nobody to ask.
