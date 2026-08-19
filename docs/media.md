# Video and audio

> Owns: src/qml/CameraTile.qml
> Owns: src/qml/RadioPanel.qml
> Owns: src/app/Cameras.hpp
> Owns: src/app/Cameras.cpp
> Owns: src/app/Radio.hpp
> Owns: src/app/Radio.cpp
> See:  docs/scene.md docs/state.md qt-hmi-buildroot/docs/build-pipeline.md

Five RTSP tiles from `camera-url` and one internet radio from `radio-url`, all through
QtMultimedia. One `Repeater` over the URL list, so the tile count is whatever the config
says and nothing anywhere assumes five.

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
it: while playing, `position` must advance between ticks or the stream is called stalled.
Delete that timer and a camera switched off mid-stream reads as live indefinitely.

Reconnecting is `source = ""` followed by the URL again. A `stop()`/`play()` pair on the same
source makes the backend seek instead, which on a live stream is an RTSP `PAUSE` the server
answers with 405 and a tile that never comes back.

`Component.onCompleted` connects, and `onUrlChanged` deliberately does not: inside a
`Repeater` the `url` binding is evaluated during creation and `Component.onCompleted` runs
after it, so wiring both opens every stream twice.

## The remembered station

`RadioPanel` persists the station index through QML's `Settings`, which is `QSettings`, which
needs `QCoreApplication::setOrganizationName`/`setApplicationName` — set in `main.cpp` — and
a writable config location on the target. Where it cannot be written the station simply does
not survive a restart and nothing else breaks.

`Radio.index` and the persisted value are wired one direction each way rather than bound
together: a two-way binding fights itself the first time a button moves the station.

`Radio` clamps the index to the list, so a remembered station from a longer list cannot leave
the panel pointed at a URL that no longer exists.

## What the image has to carry

Linking `Qt6::Multimedia` is not enough; none of this is resolved until runtime:

* the `QtMultimedia` QML module,
* a media backend — Qt's ffmpeg backend, or gstreamer with `rtspsrc` (in `gst1-plugins-good`),
* ALSA userspace and a card for the radio to play through,
* video decode reachable from userspace.

A build that links cleanly still shows five black tiles and plays nothing when any of these
is missing. The Buildroot side of it is `qt-hmi-buildroot/docs/build-pipeline.md`.
