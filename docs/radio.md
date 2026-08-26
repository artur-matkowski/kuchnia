# The radio

> Owns: src/qml/RadioPanel.qml
> Owns: src/app/Radio.hpp
> Owns: src/app/Radio.cpp
> Owns: src/app/SnapClient.hpp
> Owns: src/app/SnapClient.cpp
> See:  docs/media.md docs/volume.md docs/app.md docs/scene.md docs/input.md docs/session.md

The radio from `radio-m3u`, out of the same audio sink the cameras share. Which of them is heard is not decided here — that arbitration and the mute it
is made of are [media](docs/media.md).

## The station list is files

`radio-m3u` is a comma-separated list of extended M3U paths, read in the order it names them
and concatenated into one station list — `Radio::read()` per file, `Radio::load()` over all of
them. **One path that cannot be read does not stop the others**: it is an error naming that
path and its stations are simply not in the list, so a playlist on a share that is not mounted
is a panel that is quietly shorter rather than a panel that is empty. Only a list with no
station in any file is an error about the whole set.

Splitting is on commas with **no trimming**, so `a.m3u, b.m3u` asks for a path beginning with a
space. That is why the error quotes the path.

**Nothing ships any of those files.** The package carries none and the default is the single
`/etc/radio.m3u`, so a board that has only been installed has a radio panel with an empty
station list until someone puts one there.

**Qt exposes no now-playing title.** The stations do broadcast one — ICY `StreamTitle` is in
the stream and `ffprobe` prints it — but Qt's ffmpeg backend maps it onto no key the scene can
read. `RadioPanel`'s status line stays bound and empty rather than carrying a placeholder for
something the stream never told us.

## Two transports, and the scheme picks one

A station's URL scheme says how it is played:

| scheme | played by | synced |
|---|---|---|
| `http`, `https` | `RadioPanel`'s `MediaPlayer` | no |
| `snapcast` | a `snapclient` child, through `SnapClient` | yes, sample-accurate |

**`Radio` parses neither.** `load()` takes any non-`#` line verbatim, so a synced station is one
more line in the playlist and nothing in `src/app/Radio.cpp` knows there are two kinds:

```
#EXTINF:-1 group-title="radio", Dom (sync)
snapcast://<HOST_REDACTED>:1704/kuchnia
```

**Exactly one transport ever runs**, and the second is not a fallback beside the first:
`_apply()` releases the one this station is not before starting the one it is, and a snapcast
station holds no `source` at all. `_wanted` still drives both, which is why `Cctv.radioPlaying`
and the camera mute know about neither.

**Host, port and room are all required**, and a line missing any of them fails with itself
quoted. snapclient would supply the last two on its own — port 1704, and a `hostID` off the MAC
address — and the room then plays under a name nobody chose, which reads in snapweb exactly like
one that was configured. The path segment is that `hostID`, which is what keeps per-room volume
and grouping attached to a name.

**The child's environment is passed through untouched.** `PULSE_SERVER` comes from the unit
([session](docs/session.md)), and that is the only reason it finds this board's shared server.

**`--player pulse` is passed explicitly.** The default is `alsa`, and here the device belongs to
pipewire-pulse — an ALSA client against it is silence or a fight, never an error that names
itself.

## Only a clock catches a server that is not there

**snapclient retries a server that is not there for ever, without exiting.** Left alone the card
sits on `connecting` and nothing ever contradicts it, so `SnapClient` fails the panel after ten
seconds with no `ServerSettings - ` line on the child's stderr.

That literal is where `live` comes from and nothing else is a substitute: it is logged only once
the server has answered hello, and a socket opens against a server that then drops the client
just the same. A reconnect logs it again, which is what returns the card to `live` on its own.

Failure is read off AixLog's `[Error]` / `[Fatal]` severity stamp and never off the messages.
The first thing snapclient says when its server disappears is `Error reading message header of
length 0: End of file`, which shares no substring with `Error: `, `Exception: ` or `Failed to
send hello request`.

**A server that goes quiet with its socket still open reads as `live`.** It is the same silent
failure the camera watchdog exists to catch ([media](docs/media.md)), and there is nothing
equivalent here.

`--player file:…` into a `QAudioSink` is the obvious reach from `CameraFeed` and it destroys
what snapcast is for: the client's own player schedules each chunk against the server's clock,
and a sink in between puts back the independent buffering that makes two rooms flange.

## Stopping drops the stream

`player.source` follows `_wanted`, through `_apply()` and nowhere else. Stopping clears the
source instead of pausing the player, because a paused stream resumes where its buffer left
off — minutes behind the broadcast — rather than at what is on air. Starting reopens the
connection, which is what `connecting` is for and why the button is not instant; that cost is
the behaviour and not a fault to be tuned away. Nothing is opened at startup, and a station
chosen while the radio is stopped opens nothing either.

Binding `source` onto `Radio.url` instead is the one change here that stops the whole screen.
Assigning `source` waits for whatever the player is already opening, on the GUI thread, and a
binding leaves nowhere to hold that off — see [app](docs/app.md). An assignment made while an
open is in flight is kept in `_pending` and made again when that open lands, which is why
`_apply()` has to stay idempotent.

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
