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

## RTSP does not play under Qt 6.8's ffmpeg backend

Against the `go2rtc` server these cameras sit behind, `QMediaPlayer` opens the stream, reports
`hasVideo`, builds an h264 decoder — and then delivers not one frame. `mediaStatus` stops at
`BufferingMedia`, `position` stays 0, and no packet is ever read off the socket. It is not the
tiles: a twenty-line `QMediaPlayer` + `QVideoSink` program with no QML in it does exactly the
same, while the same program plays a local MP4 and a live MPEG-TS over UDP normally. `ffprobe`
and `ffmpeg` read the same RTSP URLs over the same libraries without trouble, so the library is
not the problem either — the backend's use of it is.

Nothing at the `QMediaPlayer` API reaches it: disabling the audio track, deferring `play()`
until `LoadedMedia`, `QT_FFMPEG_PROTOCOL_WHITELIST`, forcing software decode, and go2rtc's
`?video=h264` all leave it at zero frames. A camera reaches these tiles over a protocol the
backend actually feeds — go2rtc's HTTP MP4 endpoint, or MPEG-TS — or through a decoder this
repository owns. `camera-url` is a plain URL list precisely so the first is a config change.

`method SETUP failed: 461 Unsupported transport` on startup is *not* that failure and not any
failure: the server refuses UDP, ffmpeg retries over TCP by itself and succeeds. The line is
permanent, one per camera, and Qt exposes no way to ask for TCP up front.

## What the image has to carry

Linking `Qt6::Multimedia` is not enough; none of this is resolved until runtime:

* the `QtMultimedia` QML module,
* a media backend — Qt's ffmpeg backend, or gstreamer with `rtspsrc` (in `gst1-plugins-good`),
* ALSA userspace and a card for the radio to play through,
* video decode reachable from userspace.

A build that links cleanly still shows five black tiles and plays nothing when any of these
is missing. The Buildroot side of it is `qt-hmi-buildroot/docs/build-pipeline.md`.
