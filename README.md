# qt-qml-hmi — a QML application on bare DRM/KMS

A Qt Quick application that draws straight onto a display through `eglfs` on KMS, with no
X11, no Wayland, no compositor and no software rasteriser behind it.

It shows a house across two screens the arrow keys cycle between: five RTSP cameras beside a
clock and the hot water tank on one, and the gate's state and its controls, the tank over the
last day, the weather forecast and an internet radio on the other. Behind it
are three clients of the <REDACTED> — PostgreSQL, HTTP and MQTT — each on its own thread. This
repository is where the *application* is built — screens, state, interaction — and Qt Quick
is what draws it.

## The split

There are two application repositories, and they are deliberately different in kind:

| | `drm-hmi` | `qt-qml-hmi` |
|---|---|---|
| What it is | A renderer, written from the DRM device up | An application, written on top of Qt Quick |
| Where the effort goes | The backend: the seam, the context, the asset database | The product: what it shows and what it does |
| Graphics code here | All of it | None — Qt owns the scene graph |

A problem here that wants a renderer seam, a backend switch or a scene-graph node belongs in
`drm-hmi` instead. That is the whole reason this repository exists separately.

## Documentation

**[docs/INDEX.md](docs/INDEX.md) is the entry point.** Each node names the files it owns and
carries the failure modes that present silently. Read it before reading code. Working rules
for this repository are in [CLAUDE.md](CLAUDE.md).

## Build

```sh
scripts/build.sh host          # a window on this desktop
scripts/build.sh host --run
scripts/build.sh board         # the cross build the image packages
```

Needs Qt 6.5 or later with the `Gui`, `Qml` and `Quick` modules, and `QtQuick.Shapes` at
runtime — part of `qtdeclarative`, so present wherever Quick is. Then Poco (`Foundation`,
`Net`, `NetSSL`, `JSON`), `libpqxx` and `paho-mqtt-cpp` for the integrations. On Debian:

```sh
sudo apt install libpoco-dev libpqxx-dev libpaho-mqttpp-dev libpaho-mqtt-dev
git submodule update --init --recursive        # deps/, built from source
```

`board` reads `scripts/toolchain.cmake`: copy `scripts/toolchain.cmake.example`, point it at
this machine's cross toolchain, and note the `QT_HOST_PATH` line — a Qt cross build runs
`moc`, `rcc` and `qmlcachegen` on the build machine and a plain toolchain file names none of
them. See [docs/targets.md](docs/targets.md).

There is no Buildroot, qmake or autotools vocabulary anywhere in this repository. The
CMakeLists takes its compiler and sysroot from the caller, so it cross-builds unmodified.

## Run

```
qt-hmi [--configpath <file>] [-platform <qpa>]
```

Parameters come from `/etc/qt-hmi.conf`, then the environment, then the command line, each
overriding the one before; `--help` lists them. On a desktop the default QPA platform is whatever the session
provides; on the board it is `eglfs`, which takes the whole connector and needs the display
to itself. Qt's KMS backend becomes DRM master, so **it cannot run while anything else owns
the display** — including `drm-hmi`.

## Where this runs

The **qt-hmi-buildroot** repository packages this into a purpose-built Raspberry Pi 5 Linux image
— Buildroot, BusyBox init, Mesa's `v3d` driver, one application started at boot on HDMI —
and consumes this repository as a git submodule. Everything about the board, the image and
the packaging is documented there.

Nothing here depends on that. The application builds and runs on any Linux machine with Qt 6.

## Licence

MIT.
