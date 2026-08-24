# Documentation index

The map of this repository. **Start every task here**, follow the link, read the node, then
read the code it names. Paths are repo-relative, resolved from the repository root and not
from the file you are reading.

A QML application on a Raspberry Pi 4, drawn by Qt Quick fullscreen in the board's desktop
session. The weight sits in what it shows and what it does, not in a rendering architecture:
that is `drm-hmi` next door, and a problem here wanting a renderer seam belongs there.

The scene is a dashboard of the house across five contexts the two context keys cycle
between: five RTSP cameras beside a clock and the hot water tank on one; the gate's state and
its controls, the tank over the last day, the weather forecast and an internet radio on the
compact screen; and the weather on its own on the last. Each forecast screen is two contexts -
one per span it carries - and the two do not carry the same pair. The menu key puts all four
screens on at once as miniatures to choose between, with a settings screen behind them where
every key the panel answers is bound. Behind all of it are three clients of the <REDACTED> -
PostgreSQL, HTTP and MQTT - each on its own thread, reaching the scene through one seam.

## Nodes

| Node | Covers |
|---|---|
| [app](docs/app.md) | The process and the QML module: the error that does not exit, the order that must not move, the font in the binary |
| [state](docs/state.md) | The seam: how a worker thread's data becomes a QML property without corrupting one |
| [contexts](docs/contexts.md) | The contexts the two context keys cycle, the forecast spans among them, and where an element's animation is written |
| [carousel](docs/carousel.md) | The chooser on the menu key: whole screens shrunk into a strip, and the copies that must not overlap the originals |
| [input](docs/input.md) | Every key press: the action it becomes, the file the bindings are kept in, and the row that swallows the keyboard |
| [scene](docs/scene.md) | The panels and the charts, the window a forecast is drawn through, and the QML names that are already taken |
| [media](docs/media.md) | The five cameras: the mute that a mixer cannot see, and the dead stream that reports nothing |
| [radio](docs/radio.md) | The internet radio: the station that is assigned and never bound, and the title Qt will not hand over |
| [integrations](docs/integrations.md) | The three network clients, the logger that drops lines until told where to write, and the settings that fail quietly |
| [database](docs/database.md) | The archive client: centidegrees, and a table with no index on its timestamp |
| [rest](docs/rest.md) | The HTTP client: a forecast field that goes missing without an error |
| [mqtt](docs/mqtt.md) | The broker client: the callback thread that must not block, and a refusal that names why |
| [targets](docs/targets.md) | The desktop build and the package's cross build, and what a Qt cross build needs beyond a compiler |
| [packaging](docs/packaging.md) | The `.deb`, the two channels it is published to, and the dependencies nothing can see |
| [session](docs/session.md) | How the application gets on screen: the target that is never reached, and the variable systemd does not have |
| [rtsp](docs/rtsp.md) | Whether a tile that will not come up is the stream, the network or Qt: the two tools that tell them apart |
| [diagnostics](docs/diagnostics.md) | Where the GUI thread was when it stopped answering: the watchdog that reports mid-freeze, and how one is captured |

## Navigating

```sh
grep -l '^> Owns:.*main.cpp' docs/*.md   # which node owns this file?
grep '^> Owns:' docs/*.md                # the whole code-to-doc map
./docs/check-docs.sh                     # validate after editing docs/
```
A tracked file in no `> Owns:` line is a gap `check-docs.sh` lists — close it, per [CLAUDE.md](CLAUDE.md).
