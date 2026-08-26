# The radio

> Owns: src/qml/RadioPanel.qml
> Owns: src/app/Radio.hpp
> Owns: src/app/Radio.cpp
> Owns: src/app/SnapClient.hpp
> Owns: src/app/SnapClient.cpp
> See:  docs/media.md docs/volume.md docs/app.md docs/scene.md docs/input.md docs/session.md

The radio from `radio-m3u`, out of the audio sink the cameras share. Which of the two is heard
is [media](docs/media.md)'s, not this node's.

## The station list is files

`radio-m3u` is a comma-separated list of extended M3U paths, read in order and concatenated
into one station list — `Radio::read()` per file, `Radio::load()` over all of them. It splits
on commas with **no trimming**, so `a.m3u, b.m3u` asks for a path beginning with a space, which
is why the error quotes the path.

**One path that cannot be read does not stop the others**: it is an error naming that path, and
a playlist on a share that is not mounted is a panel that is quietly shorter rather than one
that is empty. Only a list with no station in any file is an error about the whole set.

**Nothing ships any of those files.** The default is the single `/etc/radio.m3u` and the
package carries no such file, so a board that has only been installed has an empty station
list until someone puts one there.

**Qt exposes no now-playing title.** The stations do broadcast one — ICY `StreamTitle` is in the
stream and `ffprobe` prints it — but Qt's ffmpeg backend maps it onto no key the scene can read,
so `RadioPanel`'s status line stays bound and empty rather than carrying a placeholder.

## Two transports, and the scheme picks one

A station's URL scheme says how it is played:

| scheme | played by | synced |
|---|---|---|
| `http`, `https` | `RadioPanel`'s `MediaPlayer` | no |
| `snapcast` | a `snapclient` child, through `SnapClient` | yes, sample-accurate |

**`Radio` parses neither.** `read()` takes any non-`#` line verbatim, so `snapcast://host:1704/room`
is one more line in a playlist and nothing in `src/app/Radio.cpp` knows there are two kinds.

**Exactly one transport ever runs**, and the second is not a fallback beside the first:
`_apply()` releases the one this station is not before starting the one it is, and a snapcast
station holds no `source` at all. `_wanted` still drives both, which is why `Cctv.radioPlaying`
and the camera mute know about neither.

**Host, port and room are all required**, and a line missing any of them fails with itself
quoted. Left out, snapclient supplies port 1704 and a `hostID` off the MAC address on its own,
and the room then plays under a name nobody chose — which reads in snapweb exactly like one that
was configured. The path segment is that `hostID`, and it is what keeps per-room volume and
grouping attached to a name.

**The child's environment is passed through untouched.** `PULSE_SERVER` comes from the unit
([session](docs/session.md)), and that is the only reason it finds this board's shared server.

**`--player pulse` is passed explicitly.** The default is `alsa`, and here the device belongs to
pipewire-pulse — an ALSA client against it is silence or a fight, never an error that names
itself.

## Only a clock catches a server that is not there

**snapclient retries a server that is not there for ever, without exiting**, so the card would
sit on `connecting` with nothing ever contradicting it. `SnapClient` fails the panel after ten
seconds with no `ServerSettings - ` line on the child's stderr.

That literal is where `live` comes from and nothing else is a substitute: it is logged once the
server has answered hello — a socket opens against a server that then drops the client just the
same — and a reconnect logs it again, which returns the card to `live` on its own.

Failure is read off AixLog's `[Error]` / `[Fatal]` severity stamp and never off the messages: the
first thing snapclient says when its server disappears is `Error reading message header of length
0: End of file`, which shares no substring with `Error: ` or `Failed to send hello request`.

**A server that goes quiet with its socket still open reads as `live`.** It is the silent
failure the camera watchdog exists to catch ([media](docs/media.md)); there is none here.

`--player file:…` into a `QAudioSink` is the reach from `CameraFeed`, and it destroys what
snapcast is for: the client's player schedules each chunk against the server's clock, and a
sink in between puts back the buffering that makes two rooms flange.

## Stopping drops the stream

`player.source` follows `_wanted`, through `_apply()` and nowhere else. Stopping clears the
source instead of pausing the player, because a paused stream resumes where its buffer left
off — minutes behind the broadcast — rather than at what is on air. Starting reopens the
connection, which is what `connecting` is for and why the button is not instant. Nothing is
opened at startup, and a station chosen while the radio is stopped opens nothing either.

Binding `source` onto `Radio.url` instead is the one change here that stops the whole screen.
Assigning `source` waits for whatever the player is already opening, on the GUI thread, and a
binding leaves nowhere to hold that off — see [app](docs/app.md). An assignment made while one
is in flight is kept in `_pending` and made again when it lands, which is why `_apply()` has to
stay idempotent.

**What the radio publishes is what it was asked for, not what its player is doing.**
`RadioPanel` binds `_wanted` onto `Cctv.radioPlaying`; taken from `playbackState` instead, a
station that drops mid-song would let a camera into the room until it reconnected.

## The station index, remembered and re-read

`RadioPanel` persists the index through QML's `Settings`, which is `QSettings` and needs the
organisation and application names `main.cpp` sets, plus a writable config location on the
target. Where it cannot be written the station does not survive a restart and nothing else
breaks. `Radio.index` and the persisted value are wired one direction each way rather than
bound together: a two-way binding fights itself the first time a button moves the station.

`Radio.reload()` re-reads every playlist — it is the refresh key on the compact screen,
[input](docs/input.md) — so the index has to survive a file edited under it as it survives one
edited between runs. `Radio` clamps it to the list, and:

**`urls`, `names` and `count` must never go back to `CONSTANT`.** Such a property is read once
and cached, so the files would be re-read with the panel still drawing the previous list and
nothing would say so.

**The selected station is kept by URL and not by position**, or a station added above the one
playing changes what is playing.

**The signals go out in one order — `stationsChanged`, `stationLost`, `indexChanged`.**
`RadioPanel` clears `_wanted` on the second and applies it on the third. Reversed, `_apply()`
runs while the panel still wants a station and opens whatever the clamped index landed on
before closing it again.

A station in none of the files any more is `stationLost`, and the radio stops rather than
retuning to the neighbour the clamp leaves it on.
