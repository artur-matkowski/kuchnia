# Diagnosing a camera

> Owns: scripts/probe-rtsp.sh
> Owns: tools/rtsp-probe/CMakeLists.txt
> Owns: tools/rtsp-probe/main.cpp
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
stream keeps arriving. Every URL is measured on all three transports.

`rtsp-probe` draws the same tiles through the same `VideoOutput` two ways. `--backend ffmpeg`
builds a `CameraFeed` — **the application's own path**, the same source file, so a fix here is a
fix on the panel. `--backend qt` puts a `MediaPlayer` on the same sink instead, and is the only
place left in the repository where Qt opens a camera. That makes it the regression instrument:
it is what a change to the decode path is measured against.

Under `--backend qt` the feed is never started. It holds the sink and counts what arrives,
which is why `CameraFeed::noteFrame()` tolerates a clock that was never started.

**Neither backend proves libav is absent.** `import QtMultimedia` loads Qt's media backend
whichever is chosen, because `VideoOutput` comes out of it.

## What fails silently in these tools

* **The harness redacts on the way in.** Every `camera-url` carries a password and a capture is
  pasted into a ticket, so nothing under `logs/rtsp-<stamp>/` ever holds a credential —
  redaction at report time would be one forgotten path away from publishing one.
* **`rtsp-probe` never retries and the application does.** A stream silently reopened is the
  measurement erased; what a retry costs is usually the question being asked.
* Everything about slicing the pipe — the geometry read off ffmpeg's own header,
  `-fps_mode passthrough`, the single place frames are counted — belongs to `CameraFeed` and
  is [media](docs/media.md).

## What they established, measured on a desktop

Against the five configured cameras and the same picture proxied through go2rtc, **before** the
application's decode path was changed:

* **ffmpeg alone opened every one of them in 2.5–3.1 s** and held them at their full rate with
  no errors. No transport was meaningfully faster than another.
* **Qt's `MediaPlayer` took 5.3–6.3 s on those same cameras** — roughly double, on the same
  machine, in the same window.
* **Qt could not play the go2rtc-proxied stream at all**: `PlayingState`, `BufferedMedia`,
  `position` pinned at 0, no frame ever, and no error. ffmpeg opened it in 2.5 s.
* `method SETUP failed: 461 Unsupported transport` is go2rtc refusing UDP. The cameras never
  emit it, on any transport.
* The `H265/ch1/sub/av_stream` paths carry H.264 Main, and the proxy is a repack: same codec,
  size, pixel format and rate as the camera behind it.

Those three findings are why `CameraFeed` exists. The application now opens all five in
2.6–3.3 s and plays the proxied stream, which is what `--backend qt` is kept to re-measure
against.

## What the sound on a zoomed camera costs

Time to the first PCM bytes off the audio child's pipe, three runs of each, against the same
five streams. Two of them — `podjazd_sub` and `grill_sub` — carry an audio track at all.

| the audio child asks for | with a microphone | without one |
|---|---|---|
| the whole stream, `-vn` | 3.3–5.3 s | 2.9–3.2 s to exit 234 |
| `-allowed_media_types audio` | **0.30–0.34 s** | **0.13 s to exit 234** |

**The video track is the whole of the difference**, and neither of the two things a reader
reaches for next moves it: `-probesize 32 -analyzeduration 0 -fflags nobuffer` on top measures
0.36–0.38 s, and asking go2rtc for an audio-only view of the same stream — `?audio` on the
URL — measures 0.30–0.35 s. The flag is already at the floor, so the panel carries no second
URL per camera and go2rtc is not configured for this at all.

A desktop is not the board. None of the above is a statement about the Pi 4 until it has been
run there — [targets](docs/targets.md), and `CLAUDE.md` on hardware being the oracle.
