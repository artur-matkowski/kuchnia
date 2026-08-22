# Video and audio

> Owns: src/qml/CameraTile.qml
> Owns: src/qml/RadioPanel.qml
> Owns: src/app/Cameras.hpp
> Owns: src/app/Cameras.cpp
> Owns: src/app/Radio.hpp
> Owns: src/app/Radio.cpp
> See:  docs/scene.md docs/state.md docs/contexts.md qt-hmi-buildroot/docs/build-pipeline.md docs/input.md

Five RTSP tiles from `camera-url` and one internet radio from `radio-m3u`, all through
QtMultimedia. The tiles reach the cameras directly; nothing sits in between.

`VideoOutput` preserves aspect. The cells are cut to the streams' own 16:9, so there is
normally nothing to fit; a camera that is not 16:9 letterboxes rather than being stretched
into a shape it never had.

## One audio sink, and it belongs to the radio

Every `CameraTile` assigns an `AudioOutput` and mutes it. Leaving `audioOutput` unset is not
equivalent: it is silent on some backends and audible on others, and the cameras that carry
sound are exactly the ones that would establish which — after the radio has already been
mixed with a doorway.

**The mute is applied in software, not at the sink.** PulseAudio reports these streams as
unmuted and at 100%, because Qt zeroes the samples before they reach it. Checking a mixer
therefore proves nothing; measuring the output does. Recording the sink monitor with the
radio stopped gives digital silence.

## A dead camera does not report itself

Three different things happen when a stream goes away, and only one of them is an error:

* **The peer refuses the connection.** `onErrorOccurred` fires. Easy.
* **The peer closes the stream.** No error at all — `mediaStatus` becomes `EndOfMedia`,
  playback stops, and the tile paints its last frame. This is what a camera reboot looks
  like.
* **The peer stops sending.** *Nothing* fires. `playbackState` stays `PlayingState`,
  `mediaStatus` stays put, and the tile keeps its green "live" badge over an hour-old
  picture for as long as the process runs.

The third is the one that matters and the `watchdog` timer is the only thing that catches
it. Liveness is counted in frames delivered to `VideoOutput.videoSink`, and nothing else is
a substitute: on a live stream whose container declares no duration — every camera here —
`position` never leaves 0 and `playbackState` is `PlayingState` from the moment `play()`
returns. A watchdog reading either of those calls a perfectly healthy camera stalled and
tears it down on a timer, forever, and the tiles stay black because nothing survives long
enough to paint.

Two budgets, because connecting and running fail on different timescales. A stream that has
delivered a frame must keep delivering one every `stallTimeoutMs`. A stream that has not
delivered its first frame yet gets `connectTimeoutMs`, which is much longer: an RTSP session
that has to fall back from UDP to TCP takes seconds to hand over a picture. The watchdog also
stands down while `retry` is pending — it ticks faster than the retry it is waiting for, and
re-arming that timer on every tick pushes its deadline out of reach and the reconnect never
happens.

Reconnecting is `source = ""` followed by the URL again. A `stop()`/`play()` pair on the same
source makes the backend seek instead, which on a live stream is an RTSP `PAUSE` the server
answers with 405 and a tile that never comes back.

`Component.onCompleted` connects, and `onUrlChanged` deliberately does not: the `url` binding
is evaluated during creation and `Component.onCompleted` runs after it, so wiring both opens
every stream twice.

## The station list is a file

Stations come from the extended M3U at `radio-m3u`, parsed in `Radio::load()`: the text after
the last comma of an `#EXTINF` line is the name, the next line that is neither blank nor a
directive is the URL. A path that cannot be read, and a file with no entries, are both an
error in the log and a radio with no stations. Shipping that file to the board is
`qt-hmi-buildroot`'s job; nothing here creates it.

**Qt exposes no now-playing title.** The stations do broadcast one — ICY `StreamTitle` is in
the stream and `ffprobe` prints it — but Qt's ffmpeg backend maps it onto no key the scene
can read: a playing MP3 station offers `Duration`, `FileFormat`, `AudioCodec` and
`AudioBitRate` and nothing else. `RadioPanel`'s status line stays bound and empty, rather
than carrying a placeholder for something the stream never told us.

## The remembered station

`RadioPanel` persists the station index through QML's `Settings`, which is `QSettings`, which
needs `QCoreApplication::setOrganizationName`/`setApplicationName` — set in `main.cpp` — and
a writable config location on the target. Where it cannot be written the station simply does
not survive a restart and nothing else breaks.

`Radio.index` and the persisted value are wired one direction each way rather than bound
together: a two-way binding fights itself the first time a button moves the station.

`Radio` clamps the index to the list, so a remembered station from a longer playlist cannot
leave the panel pointed at a URL that no longer exists.

## A stream cannot be paused, so leaving a screen is expensive

A tile that goes off screen has only one way to stop decoding: tear the session down and open
a fresh one on the way back. `pause()` is not an option — on a live stream it is an RTSP
`PAUSE`, which these cameras answer with 405, and the tile never comes back.

Reopening one of these cameras takes **five to six seconds**, measured. That is the number
`camera-hold-ms` is weighed against: a tile keeps its stream for that long after its context
leaves the screen, so a glance at the other screen costs nothing and only a real stay pays
the reconnect. **Negative never disconnects.** Zero disconnects as soon as the transition
settles, which is the setting that makes every return cost six seconds of black tiles.

Two things a tile must not do while it is torn down, and neither announces itself:

* **`_retryLater()` returns early when `_down`.** Clearing the source is itself reported as
  `EndOfMedia`, so without that guard the teardown arms a retry that reopens the stream off
  screen — the decoder this was meant to stop, running anyway.
* **The watchdog stops with it.** A tile that was asked to stop is otherwise reported stalled,
  and the backoff climbs while nothing is looking at it.

`method SETUP failed: 461 Unsupported transport` on startup is not a failure at all: the
camera refuses UDP, ffmpeg retries over TCP by itself and succeeds. The line is permanent,
one per camera, and Qt exposes no way to ask for TCP up front.

## What the image has to carry

Linking `Qt6::Multimedia` is not enough; none of this is resolved until runtime:

* the `QtMultimedia` QML module,
* a media backend — Qt's ffmpeg backend, or gstreamer with `rtspsrc` (in `gst1-plugins-good`),
* ALSA userspace and a card for the radio to play through,
* video decode reachable from userspace.

A build that links cleanly still shows five black tiles and plays nothing when any of these
is missing. The Buildroot side of it is `qt-hmi-buildroot/docs/build-pipeline.md`.
