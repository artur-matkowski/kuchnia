# Documentation index

The map of this repository. **Start every task here**, follow the link, read the node, then
read the code it names. Paths are repo-relative, resolved from the repository root and not
from the file you are reading; a `qt-hmi-buildroot/` prefix marks a node in the image repository
that consumes this one.

A QML application on a Raspberry Pi 5, drawn by Qt Quick straight onto KMS through `eglfs`.
The weight is meant to sit in the application — what it shows and what it does — and not in
a rendering architecture. The repository next to it, `drm-hmi`, is where that architecture
lives; when a problem here wants a renderer seam, it belongs there instead.

Today the scene is one spinning triangle, and beside it three clients of the <REDACTED> -
PostgreSQL, HTTP and MQTT - that log what they see and touch nothing on screen.

## Nodes

| Node | Covers |
|---|---|
| [app](docs/app.md) | The process and the QML module: the error that does not exit, the URI written twice |
| [qml](docs/qml.md) | The scene: rotating about a centroid, and why nothing draws text |
| [integrations](docs/integrations.md) | The three network clients, the logger that drops lines until told where to write, and the settings that fail quietly |
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
