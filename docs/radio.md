# The radio

> Owns: src/qml/RadioPanel.qml
> Owns: src/app/Radio.hpp
> Owns: src/app/Radio.cpp
> See:  docs/media.md docs/app.md docs/scene.md docs/input.md

One internet radio from `radio-m3u`, through QtMultimedia and out of the same audio sink the
cameras share. Which of them is heard is not decided here — that arbitration and the mute it
is made of are [media](docs/media.md).

## The station list is a file

Stations come from the extended M3U at `radio-m3u`, parsed in `Radio::load()`. A path that
cannot be read, and a file with no entries, are both an error in the log and a radio with no
stations. **Nothing ships that file.** The package does not carry it and the default path
points at `/etc/radio.m3u`, so a board that has only been installed has a radio panel with an
empty station list until someone puts one there.

**Qt exposes no now-playing title.** The stations do broadcast one — ICY `StreamTitle` is in
the stream and `ffprobe` prints it — but Qt's ffmpeg backend maps it onto no key the scene can
read. `RadioPanel`'s status line stays bound and empty rather than carrying a placeholder for
something the stream never told us.

## The station is assigned and never bound

`player.source` is written by `_station()`, and binding it onto `Radio.url` instead is the one
change here that stops the whole screen. Assigning `source` waits for whatever the player is
already opening, on the GUI thread, and a binding leaves nowhere to hold that off — see
[app](docs/app.md). A station chosen while one is being opened is kept in `_stationPending`
and applied when the open lands.

**What the radio publishes is what it was asked for, not what its player is doing.**
`RadioPanel` binds `_wanted` onto `Cctv.radioPlaying`; taken from `playbackState` instead, a
station that drops mid-song would let a camera into the room until it reconnected.

## The remembered station

`RadioPanel` persists the station index through QML's `Settings`, which is `QSettings` and
needs the organisation and application names `main.cpp` sets, plus a writable config location
on the target. Where it cannot be written the station does not survive a restart and nothing
else breaks.

`Radio.index` and the persisted value are wired one direction each way rather than bound
together: a two-way binding fights itself the first time a button moves the station. `Radio`
clamps the index to the list, so a remembered station from a longer playlist cannot leave the
panel pointed at a URL that no longer exists.
