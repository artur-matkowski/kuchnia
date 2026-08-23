# Video and audio

> Owns: src/qml/CameraTile.qml
> Owns: src/app/Cameras.hpp
> Owns: src/app/Cameras.cpp
> See:  docs/radio.md docs/app.md docs/scene.md docs/state.md docs/contexts.md qt-hmi-buildroot/docs/build-pipeline.md docs/input.md

Five RTSP tiles from `camera-url`, through QtMultimedia. The tiles reach the cameras directly;
nothing sits in between, and the radio they share an audio sink with is [radio](docs/radio.md).
`VideoOutput` is set to `Stretch` and not to a preserved aspect: the cells are cut to the
streams' own 16:9 so there is nothing to fit, and a black bar down one tile of five reads as a
tile that has stopped working. A zoomed tile is a little wider than 16:9 and is stretched by
that much.

## One audio sink, and the radio wins

Every `CameraTile` assigns an `AudioOutput` whether or not it is wanted, and mutes it when it
is not. Leaving `audioOutput` unset is not equivalent: it is silent on some backends and
audible on others, and the cameras that carry sound are exactly the ones that would establish
which — after the radio has already been mixed with a doorway.

`Cctv.audible` decides, and at most one camera is ever heard: the one filling the screen, while
the radio is not wanted and CCTV is the context on screen. Nothing is configured about which
cameras carry a microphone, because nothing has to be — an unmuted stream with no audio track
is silent by itself.

**The mute is applied in software, not at the sink.** PulseAudio reports these streams as
unmuted and at 100%, because Qt zeroes the samples before they reach it. Checking a mixer
therefore proves nothing; measuring the output does.

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
delivered a frame must keep delivering one every `stallTimeoutMs`. One that has not gets
`connectTimeoutMs`, which is much longer and is counted from the backend's last word rather
than from the request: the UDP-to-TCP fallback below takes seconds and happens inside an open
the watchdog is not allowed to touch. So it stands down entirely while `_loading`, and while
`retry` is pending — that timer ticks faster than the retry it is waiting for, and re-arming it
on every tick pushes the deadline out of reach so the reconnect never happens.

Reconnecting is `source = ""` followed by the URL again. A `stop()`/`play()` pair on the same
source makes the backend seek instead, which on a live stream is an RTSP `PAUSE` the server
answers with 405 and a tile that never comes back.

**Nothing here may assign `source` while the backend is opening one.** That assignment waits
for the open on the thread that makes it, and can run the open there outright — the panel stops
for as long as the camera takes and nothing says so. `_loading` guards every assignment in the
file, including the teardown below, and the open that is left alone reports its own failure to
`onErrorOccurred`. Why it blocks is [app](docs/app.md).

`Component.onCompleted` connects and `onUrlChanged` deliberately does not: the `url` binding is
evaluated during creation and this runs after it, so wiring both opens every stream twice.

## A stream cannot be paused, so leaving a screen is expensive

A tile that goes off screen has only one way to stop decoding: tear the session down and open a
fresh one on the way back. Reopening one of these cameras takes **five to six seconds**,
measured, and that is the number `camera-hold-ms` is weighed against: a tile keeps its stream
for that long after its context leaves the screen, so a glance at another screen costs nothing
and only a real stay pays the reconnect. **Negative never disconnects.** Zero disconnects as
soon as the transition settles, which is the setting that makes every return cost six seconds
of black tiles.

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
