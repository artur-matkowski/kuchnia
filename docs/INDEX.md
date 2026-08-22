# Documentation index

The map of this repository. **Start every task here**, follow the link, read the node, then
read the code it names. Paths are repo-relative, resolved from the repository root and not
from the file you are reading; a `qt-hmi-buildroot/` prefix marks a node in the image repository
that consumes this one.

A QML application on a Raspberry Pi 5, drawn by Qt Quick straight onto KMS through `eglfs`.
The weight is meant to sit in the application — what it shows and what it does — and not in
a rendering architecture. The repository next to it, `drm-hmi`, is where that architecture
lives; when a problem here wants a renderer seam, it belongs there instead.

The scene is a dashboard of the house across five contexts the left and right arrows cycle
between: five RTSP cameras beside a clock and the hot water tank on one; the gate's state and
its controls, the tank over the last day, the weather forecast and an internet radio on the
compact screen; and the weather on its own on the last. Each forecast screen is two contexts -
one per span it carries - and the two do not carry the same pair. Up puts all four screens on
at once as miniatures to choose between, with a settings screen that is reachable no other way.
Behind it are three clients of the <REDACTED> - PostgreSQL, HTTP and MQTT - each on its own
thread, reaching the scene through one seam and never touching Qt themselves.

## Nodes

| Node | Covers |
|---|---|
| [app](docs/app.md) | The process and the QML module: the error that does not exit, the order that must not move, the font in the binary |
| [state](docs/state.md) | The seam: how a worker thread's data becomes a QML property without corrupting one |
| [contexts](docs/contexts.md) | The contexts the arrow keys cycle, the forecast spans among them, and where an element's animation is written |
| [carousel](docs/carousel.md) | The chooser on the up key: whole screens shrunk into a strip, the copies that must not overlap the originals, and the settings mockup behind it |
| [scene](docs/scene.md) | The panels and the charts, the window a forecast is drawn through, and the QML names that are already taken |
| [media](docs/media.md) | The cameras and the radio: the mute that a mixer cannot see, and the dead stream that reports nothing |
| [integrations](docs/integrations.md) | The three network clients, the logger that drops lines until told where to write, and the settings that fail quietly |
| [database](docs/database.md) | The archive client: centidegrees, and a table with no index on its timestamp |
| [rest](docs/rest.md) | The HTTP client: a forecast field that goes missing without an error |
| [mqtt](docs/mqtt.md) | The broker client: the callback thread that must not block, and a refusal that names why |
| [targets](docs/targets.md) | `host` and `board`, one cache each, and the host tools a Qt cross build needs |

## Where the rest of the answers are

This repository is a git submodule of the **qt-hmi-buildroot** image repository, which builds it
as a Buildroot package for a Raspberry Pi 5 on bare DRM/KMS. What is not the application
itself lives there and is not repeated here:

| Question | Node in the image repository |
|---|---|
| The Buildroot packaging, Qt's config, the rebuild targets | `qt-hmi-buildroot/docs/build-pipeline.md` |
| Which application autostarts, who owns the CRTC | `qt-hmi-buildroot/docs/display-pipeline.md` |
| Deploying a build to a board | `qt-hmi-buildroot/docs/image-and-flash.md` |
| A board that boots to nothing | `qt-hmi-buildroot/docs/debugging.md` |

## Navigating

```sh
grep -l '^> Owns:.*main.cpp' docs/*.md   # which node owns this file?
grep '^> Owns:' docs/*.md                # the whole code-to-doc map
./docs/check-docs.sh                     # validate after editing docs/
```
A tracked file in no `> Owns:` line is a gap `check-docs.sh` lists — close it, per [CLAUDE.md](CLAUDE.md).
