# Documentation index

The map of this repository. **Start every task here**, follow the link, read the node, then
read the code it names. Paths are repo-relative, resolved from the repository root and not
from the file you are reading.

A QML application on a Raspberry Pi 4, drawn by Qt Quick fullscreen in the board's desktop
session. The weight sits in what it shows and what it does, not in a rendering architecture:
that is `drm-hmi` next door, and a problem here wanting a renderer seam belongs there.

The scene is a dashboard of the house across five contexts the two context keys cycle between:
five RTSP cameras beside a clock and the hot water tank on one; the gate's state and its
controls, the tank over the last day, the weather forecast and an internet radio on the compact
screen; the weather on its own, over two forecast spans that are a context each; and a map of
everyone sharing a location, pannable to one of them. The menu key puts all five screens on at
once as miniatures to choose between, with a settings screen behind them where every key the
panel answers is bound. Behind all of it are four clients of the house network - PostgreSQL, two
HTTP services and MQTT - each on its own thread, reaching the scene through one seam.

## Nodes

| Node | Covers |
|---|---|
| [app](docs/app.md) | The process and the QML module: the error that does not exit, the order that must not move, the font in the binary |
| [state](docs/state.md) | The seam: how a worker thread's data becomes a QML property without corrupting one |
| [contexts](docs/contexts.md) | The contexts the two context keys cycle, the forecast spans among them, and where an element's animation is written |
| [carousel](docs/carousel.md) | The chooser on the menu key: whole screens shrunk into a strip, and the copies that must not overlap the originals |
| [input](docs/input.md) | Every key press: the action it becomes, the file the bindings are kept in, and the keys that never arrive |
| [settings](docs/settings.md) | The screen every key is bound on: the table order that is a walk, and the card that cannot take another row |
| [scene](docs/scene.md) | The panels, the type scale the board's panel is measured in, and the QML names that are already taken |
| [charts](docs/charts.md) | One line from a series: what an empty one draws, the grid that must not be a Repeater, and the window a forecast is drawn through |
| [media](docs/media.md) | The five cameras: the mute that a mixer cannot see, and the dead stream that reports nothing |
| [radio](docs/radio.md) | The internet radio: the stop that drops the stream rather than pausing it, and the title Qt will not hand over |
| [volume](docs/volume.md) | The two volume keys: the sink they move, the variable that decides which daemon hears them, and the failure nothing draws |
| [integrations](docs/integrations.md) | The three network clients, the logger that drops lines until told where to write, and the settings that fail quietly |
| [database](docs/database.md) | The archive client: centidegrees, and a table with no index on its timestamp |
| [rest](docs/rest.md) | The HTTP client: a forecast field that goes missing without an error |
| [mqtt](docs/mqtt.md) | The broker client: the callback thread that must not block, and a refusal that names why |
| [targets](docs/targets.md) | The desktop build and the package's cross build, and what a Qt cross build needs beyond a compiler |
| [packaging](docs/packaging.md) | The `.deb`, the two channels it is published to, and the dependencies nothing can see |
| [ci](docs/ci.md) | The run that builds the package: the image its dependencies are already in, and the cache that is silent when it is missing |
| [session](docs/session.md) | How the application gets on screen: the target that is never reached, and the variable systemd does not have |
| [rtsp](docs/rtsp.md) | Whether a tile that will not come up is the stream, the network or Qt: the two tools that tell them apart |
| [diagnostics](docs/diagnostics.md) | Where the GUI thread was when it stopped answering: the watchdog that reports mid-freeze, and how one is captured |
| [map](docs/map.md) | The map context: the scrape that must not live here, and the only list model in the repository |
| [whereabouts](docs/whereabouts.md) | The map panel: the plugin settings that fail silently, what a poll may not take back from the viewport, and the list that picks one person |
| [location](docs/location.md) | The server half: the Google session that cannot live on the panel, the empty roster that means two things, and the browser a person signs in on |
| [tiles](docs/tiles.md) | The map's tiles: the fetch that fails once and leaves a hole for good, and the expired tile that is better than none |
| [delivery](docs/delivery.md) | How a ticket closes: the one place a closing keyword may live, and the gate that refuses the rest |
| [versioning](docs/versioning.md) | The version folded out of the commit messages: the type that bumps nothing, and the gate that is the only thing to say so |
| [demo](docs/demo.md) | The configuration a recording is made against: public streams instead of the house, and the config file it must not read |

## Navigating

```sh
grep -l '^> Owns:.*main.cpp' docs/*.md   # which node owns this file?
grep '^> Owns:' docs/*.md                # the whole code-to-doc map
./docs/check-docs.sh                     # validate after editing docs/
```
A tracked file in no `> Owns:` line is a gap `check-docs.sh` lists — close it, per [CLAUDE.md](CLAUDE.md).
