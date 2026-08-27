# Video and audio

> Owns: src/qml/CameraTile.qml
> Owns: src/app/CameraFeed.hpp
> Owns: src/app/CameraFeed.cpp
> Owns: src/app/Cameras.hpp
> Owns: src/app/Cameras.cpp
> See:  docs/radio.md docs/volume.md docs/app.md docs/scene.md docs/state.md docs/contexts.md docs/packaging.md docs/input.md docs/rtsp.md

Five RTSP tiles from `camera-url`. **Qt neither demuxes nor decodes any of them**: `CameraFeed`
runs `ffmpeg` as a child process, reads raw `yuv420p` frames off its stdout and hands each to
the `QVideoSink` the tile's `VideoOutput` gave it. Qt's part is the blit. Why the streams are
not Qt's to open, and the tools that established it, are [rtsp](docs/rtsp.md).

`VideoOutput` is set to `Stretch` and not to a preserved aspect: the cells are cut to the
streams' own 16:9 so there is nothing to fit, and a black bar down one tile of five reads as a
tile that has stopped working. A zoomed tile is a little wider than 16:9 and is stretched by
that much.

## Two children, and why not one

A pipe carries one output. Video is on the pipe that must never be made to wait, so audio gets
its own child process and its own RTSP session rather than a second output on the first one — a
fifo nobody drains blocks the writer, and the writer is the picture.

The audio child exists **only while `audible`**, which is at most one camera in the whole
application (`Cctv.audible`, and the radio wins — [radio](docs/radio.md)). There is no mute:
silence is the absence of a process, and a zoom pays a fresh RTSP open for its sound.

**`-allowed_media_types audio` is what holds that open under half a second.** `-vn` drops the
video only after the demuxer has resolved every track it set up, so without the flag the sound
waits on the H.264 track's parameters — a keyframe — and arrives three to five seconds after the
zoom, with nothing anywhere reporting a delay. Two of these five cameras have a microphone; on
the other three the child exits 234 with `Output file does not contain any stream` a tenth of a
second later, with or without the trailing `?` on `-map 0:a:0?`, and nothing retries it.

**The `QAudioSink` is opened on the first byte, not when the child starts.** It pulls, and one
started against a process still opening its stream spends the whole open in underrun.

## The pipe's geometry is ffmpeg's to declare

`CameraFeed` reads the frame size out of ffmpeg's own output header and from nowhere else — not
from a prior `ffprobe`, not from a setting. **A frame size that disagrees with the bytes on the
pipe is a sheared, rolling picture and never an error.** The match needs two digits on each
side, or the FourCC in `rawvideo (I420 / 0x30323449)` is read as the resolution and every frame
after it is zero bytes long.

Planes are copied row by row. The mapped `QVideoFrame`'s stride is Qt's and the pipe's is the
picture's, so a straight `memcpy` of a whole plane shears every frame on any width Qt padded.

**`-fps_mode passthrough` is not a tuning knob.** A rawvideo pipe carries no timestamps, so
ffmpeg's default pads it to a constant rate: a camera sending 10 fps at a declared 25 arrives
as 25 fps of which 15 are duplicates, each decoded, copied and uploaded for nothing. The
picture looks correct either way.

`camera-transport` is **`tcp`** and not `auto`. Every stream here opens as fast on TCP as on
anything else; `auto` tries UDP first, and a peer that refuses it costs a round trip and a
`method SETUP failed: 461 Unsupported transport` in the log. None of these cameras refuses UDP.
The go2rtc proxy does, and answers on TCP alone.

## A dead camera does not report itself

Three different things happen when a stream goes away, and only one of them announces itself:

* **The peer refuses the connection.** ffmpeg exits non-zero and says why.
* **The peer closes the stream.** ffmpeg exits zero. Indistinguishable from a clean end, which
  is what a camera reboot looks like from here.
* **The peer stops sending.** *Nothing* happens. The child stays alive, its pipe goes quiet,
  and the tile paints its last frame under a green "live" badge for as long as it runs.

The third is the one that matters, and the watchdog is the only thing that catches it.
**Liveness is counted in frames delivered to the sink, and nothing else is a substitute.**
Frames are counted in exactly one place — `attach()`'s connection to `videoFrameChanged` — and
a second counter anywhere counts every frame twice.

Two budgets, because connecting and stalling fail on different timescales: a stream that has
delivered a frame must keep delivering one every five seconds, and one that has not gets
twenty, which has to clear the two to three seconds an open actually takes. The watchdog stands
down while a retry is pending — it ticks faster than the retry it is waiting for, and re-arming
on every tick pushes that deadline out of reach so the reconnect never happens.

Reconnecting is killing the child and starting another. The backoff doubles to thirty seconds
so a camera that is genuinely gone does not reconnect in a tight loop for days, and the first
frame that arrives resets it.

## Leaving a screen still costs a reconnect

A tile that goes off screen has one way to stop decoding: kill the child and start a fresh one
on the way back, which costs **two to three seconds**. That is the number `camera-hold-ms` is
weighed against: a tile keeps its stream for that long after its context leaves the screen, so
a glance at another screen costs nothing and only a real stay pays the reconnect. **Negative
never disconnects** — a decoder running for a context nobody is looking at, which costs exactly
as much as one that is. Zero disconnects as soon as the transition settles.

`start()` and `stop()` are both idempotent, and `start()` runs after `attach()`: a feed started
before it has a sink decodes frames with nowhere to put them. The scene does both in
`Component.onCompleted`, in that order.

## What the image has to carry

**`ffmpeg` is a package dependency and nothing in the binary reveals it.** A board without it
shows five tiles that fail with "No such file or directory" and retry forever. It is named in
`debian/control` by hand with the rest — [packaging](docs/packaging.md).

Linking `Qt6::Multimedia` is not enough either; none of this is resolved until runtime:

* the `QtMultimedia` QML module, for `VideoOutput` and for the radio's player,
* a reachable PulseAudio server, below.

Nothing here needs Qt's media *backend* for a camera any more, and nothing here needs video
decode reachable from userspace: ffmpeg decodes in software, in its own process, where a
decoder that hangs cannot take the GUI thread with it.

## There is no ALSA path, and no server is silent

Debian's QtMultimedia links `libpulse` and **nothing else** — no `libasound` in
`libQt6Multimedia.so.6`. A PulseAudio-protocol server is not one way to get sound out; it is
the only one, and an `audio` group with an ALSA device is not it.

**An unreachable server is a silent application, not a failed one.** Qt logs
`pa_context_connect() failed` once at startup, then runs perfectly: the scene draws, the
tiles play, and the radio connects to its station and decodes it into nothing.

Which server, and the address the unit has to name because Qt will not find it, is
[session](docs/session.md).
