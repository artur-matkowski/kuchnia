# The demo configuration

> Owns: demo/demo.conf
> Owns: demo/docker-compose.yml
> Owns: demo/hotwater.sql
> Owns: demo/roster.py
> Owns: demo/radio.m3u
> Owns: demo/keys.ini
> Owns: demo/kuchnia.gif
> See:  docs/map.md docs/tiles.md docs/media.md docs/database.md docs/rest.md docs/radio.md docs/integrations.md

A second configuration for recording the application with nothing private on screen. Every
address in it is either public or answered by a container in this directory, so the panel a
stranger brings up is the panel in the screen capture.

```sh
docker compose -f demo/docker-compose.yml up -d
scripts/build.sh host
build/host/kuchnia --configpath demo/demo.conf        # from the repository root
```

`scripts/build.sh host --run` is **not** the way in: it passes no `--configpath`, so it takes
the board's per-user config instead of this one.

## Three paths are relative, and one is the wrong file

`radio-m3u` and `key-bindings` are relative paths and `demo/docker-compose.yml` mounts by
relative path, so all of it is resolved from the **repository root** and a run started
anywhere else is a shorter station list and unbound radio keys, each reported as its own line
and neither stopping the scene.

The fourth is worse for being invisible: without `--configpath` the settings come from
`~/.config/kuchnia/config.conf`, which is a working panel pointed at the house. Nothing on
screen says which file it read.

## The forecast needs coordinates before it draws

`rest-url` carries `latitude=<set-me>&longitude=<set-me>` — no coordinate pair is written down
in this repository. open-meteo answers an error until both are filled in, and the two forecast
contexts stay empty with nothing on screen saying why.

## Why the cameras are not RTSP

`camera-transport:auto` is load-bearing. Public RTSP demo endpoints are gone — the survivors
answer nothing on 554 — so `camera-url` carries five public HLS streams instead, and
[media](docs/media.md) explains the flag they cannot take: on any transport but `auto`,
`CameraFeed` passes `-rtsp_transport` to an https input and every ffmpeg exits non-zero with
five tiles that retry for ever.

They are also somebody else's URLs, so one of them rotting is an ordinary Tuesday. A tile that
will not come up is diagnosed the way any other is — [rtsp](docs/rtsp.md) — and swapped for
another public stream in one line.

`camera-hold-ms:-1` so that cycling the contexts during a take never pays the two-to-three
second reconnect a tile costs when its context leaves the screen.

## The two containers

`db` is the tank's archive and nothing else: the `CWU_temp` schema of
[database](docs/database.md), seeded with 24 h of centidegrees. **Neither container has a
volume**, so `down` and `up` re-runs the seed — which is how rows that have aged out of the
`db-history-hours` window come back, and the only maintenance either one has.

`people` answers `people-url` with six fixed positions in Warsaw. `seen_at` is stamped per
request, so ages stay plausible in a long session; three of the six exist to exercise the map
rather than to fill it, and `demo/roster.py` says which and why.

There is no broker. The gate is not what this demo is about, so `mqtt-host` points at a
localhost nobody is listening on and the gate card carries a red `failed` badge on the compact
screen for the whole recording. Bringing an MQTT broker container up with one retained
`hc12/rx/GateClosed` is all it would take to turn that green.

## The tiles come from OpenStreetMap directly

`map-tile-url` is `tile.openstreetmap.org`, reached with the `kuchnia` User-Agent that
`MapPanel.qml` sets, rather than through the caching proxy [tiles](docs/tiles.md) documents. A
recording asks for a few hundred tiles of one city, once.

That trades away the proxy's disk cache, and [map](docs/map.md) is where the consequence is
written down: a tile whose fetch fails five times is a hole nobody repairs. `F5` on the map
context is the way back, and it blanks and redraws the whole map — so take the hole out of the
frame before recording it, not during.

## Recording

1920×1080 is the scene's compose size, and `fullscreen:false` makes the window exactly that.
Capture the window rather than a region and there is nothing to scale afterwards.

| | key | what should be on screen |
|---|---|---|
| 1 | | five tiles playing under green `live` badges, the clock and the tank beside them |
| 2 | `2`, `0` | tile two fills the screen, then the grid comes back |
| 3 | `→` | the compact screen: the tank's 24 h line, the forecast, the radio, the failed gate |
| 4 | `P` | the radio card goes `connecting`, then `live` under a station name; the title line stays empty because Qt hands over none — [radio](docs/radio.md) |
| 5 | `→` `→` | the two forecast contexts, 72 h and 7 d, banded by Warsaw's sunrise and sunset |
| 6 | `→` | the map: six markers across the city, one amber, two labels stacked at one address |
| 7 | `Space` | the carousel, all five screens as miniatures |
| 8 | `←` `→` `Return` | step along the strip and pick one. `Return` is the only way out — [input](docs/input.md) |

`demo/kuchnia.gif` is what the README draws, and it is in every clone anybody ever makes of
this repository. The recording it is cut from is not: `.gitignore` keeps `demo/*.mkv` and
`demo/*.mp4` out, so a new take is made, converted, and the source left where it fell.

The conversion, and it is a size budget rather than a taste:

```sh
ffmpeg -i <take>.mkv -vf "fps=8,scale=640:-1:flags=lanczos,split[a][b];\
  [a]palettegen=max_colors=48:stats_mode=diff[p];\
  [b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" demo/kuchnia.gif
```

Five camera tiles of moving video are what a GIF cannot compress, so the frame rate, the width
and the palette are all three spent before it fits: the same 26 seconds at 960 px and 12 fps is
21 MB, and at 720 px is still 8. **Check the byte count after re-cutting it** — a front page
that takes ten seconds to paint is the failure here, and nothing warns about it.
