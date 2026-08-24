# Diagnosing a camera

> Owns: scripts/probe-rtsp.sh
> Owns: tools/rtsp-probe/CMakeLists.txt
> Owns: tools/rtsp-probe/main.cpp
> Owns: tools/rtsp-probe/Feed.hpp
> Owns: tools/rtsp-probe/Feed.cpp
> Owns: tools/rtsp-probe/Probe.qml
> See:  docs/media.md docs/diagnostics.md docs/app.md docs/targets.md

Two tools for one question: when a tile will not come up, is it the stream, the network, or
Qt. Neither is part of the application — `scripts/probe-rtsp.sh` needs only ffmpeg, and
`rtsp-probe` is built only with `-DKUCHNIA_TOOLS=ON` and has no `install()` rule of its own.
`debian/rules` runs a plain `dh --buildsystem=cmake`, so **one `install()` line here would put
a diagnostic binary in the package.**

```sh
scripts/probe-rtsp.sh                       # every camera-url in ./config.conf
scripts/probe-rtsp.sh URL [URL...]          # a native stream beside its proxied twin
scripts/probe-rtsp.sh report logs/rtsp-<stamp>

scripts/build.sh host --tools
build/host/rtsp-probe --backend ffmpeg --config ./config.conf
build/host/rtsp-probe --backend qt      --config ./config.conf
```

## What the two halves separate

`probe-rtsp.sh` measures the stream with no Qt in the picture at all: the handshake, the open
to a first decoded frame over several cycles, and a fixed-length run that says whether the
stream keeps arriving. Every URL is measured on all three transports, because `auto` is what
Qt's backend asks for and it is not always what answers.

`rtsp-probe` draws the same tiles through the same `VideoOutput` two ways. Under `--backend
qt` a `MediaPlayer` fills it, which is the application's own path. Under `--backend ffmpeg`
an ffmpeg child process writes raw `yuv420p` down a pipe and `Feed` wraps each frame in a
`QVideoFrame` — Qt demuxes nothing, decodes nothing and opens no socket. The difference
between the two runs is the backend and nothing else.

**It is not a claim that libav is absent.** `import QtMultimedia` loads the media backend
whichever `--backend` is chosen, because `VideoOutput` comes out of it. What `ffmpeg` removes
is Qt *using* it.

## What fails silently in these tools

* **The pipe's geometry comes from ffmpeg's own output header and from nowhere else.** A
  configured size, or one carried over from an earlier `ffprobe`, is an assumption — and a
  frame size that disagrees with the bytes arriving is a sheared, rolling picture that
  reports nothing. The regex needs two digits on each side or the FourCC in `rawvideo (I420 /
  0x30323449)` is read as the resolution and every frame is zero bytes long.
* **`-fps_mode passthrough` is not a tuning knob.** A rawvideo pipe carries no timestamps, so
  ffmpeg's default pads it to a constant rate. The tile still looks correct and the frame
  count — the one number the two backends are compared on — is inflated by the duplicates.
* **Frames are counted in exactly one place**: `Feed::attach()` connecting to the sink's
  `videoFrameChanged`. A second counter beside it counts the ffmpeg backend's frames twice,
  and the obvious QML spelling of it lands *inside* the `Loader` that builds the Qt backend,
  where it silently never fires.
* **`Feed::start()` runs after the scene is loaded**, because `attach()` is a
  `Component.onCompleted`. Earlier, ffmpeg writes frames with nowhere to put them.
  `noteAsked()` exists for the same reason on the other side: the Qt backend's clock starts
  where `play()` is called, or the first-frame number is really a window-construction number.
* **The harness redacts on the way in.** Every `camera-url` carries a password and a capture
  is pasted into a ticket, so nothing under `logs/rtsp-<stamp>/` ever holds a credential —
  redaction at report time would be one forgotten path away from publishing one.

`rtsp-probe` never retries. The application does; what a retry costs is the question, and a
stream silently reopened is the measurement erased.

## What they established, measured on a desktop

Against the five configured cameras and the same picture proxied through go2rtc:

* **ffmpeg alone opens every one of them in 2.5–3.1 s** and holds them at their full rate
  with no errors. No transport is meaningfully faster than another.
* **Qt's `MediaPlayer` takes 5.3–6.3 s on those same cameras** — roughly double, on the same
  machine, in the same window. The five to six seconds in [media](docs/media.md) is Qt's
  cost, not the cameras'.
* **Qt cannot play the go2rtc-proxied stream at all.** ffmpeg opens it in 2.5 s and holds it;
  `MediaPlayer` sits in `PlayingState` at `BufferedMedia` with `position` pinned to 0 and
  delivers no frame ever, reporting no error — confirmed in `kuchnia` itself, which retries
  the 20 s connect budget forever. **A `camera-url` moved to the proxy is a black tile.**
* `method SETUP failed: 461 Unsupported transport` is go2rtc refusing UDP. The cameras never
  emit it, on any transport.
* The `H265/ch1/sub/av_stream` paths carry H.264 Main, and the proxy is a repack: same codec,
  size, pixel format and rate as the camera behind it.

A desktop is not the board. None of the above is a statement about the Pi until it has been
run there — [targets](docs/targets.md), and `CLAUDE.md` on hardware being the oracle.
