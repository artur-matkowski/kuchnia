# qt-qml-hmi — a QML application on a panel

A Qt Quick application that runs fullscreen in a Raspberry Pi's desktop session, delivered to
the board as a Debian package and started by the session it draws into.

It shows a house across screens two keys cycle between: five RTSP cameras beside a
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
scripts/build-deb.sh           # the arm64 .deb, into dist/, in a debian:trixie container
```

Needs Qt 6.5 or later with the `Gui`, `Qml` and `Quick` modules, and `QtQuick.Shapes` at
runtime — part of `qtdeclarative`, so present wherever Quick is. Then Poco (`Foundation`,
`Net`, `NetSSL`, `JSON`), `libpqxx` and `paho-mqtt-cpp` for the integrations. On Debian:

```sh
sudo apt install libpoco-dev libpqxx-dev libpaho-mqttpp-dev libpaho-mqtt-dev
git submodule update --init --recursive        # deps/, built from source
```

The `.deb` is the only cross build, and it needs no toolchain file from you — but a Qt cross
build runs `moc`, `rcc` and `qmlcachegen` on the build machine, and Debian keeps the host
package somewhere `QT_HOST_PATH` alone does not reach. See [docs/targets.md](docs/targets.md).

There is no Buildroot, qmake or autotools vocabulary anywhere in this repository. The
CMakeLists takes its compiler and sysroot from the caller, so it cross-builds unmodified —
`debian/` included, which is a package of this application and knows nothing about any image.

## Run

```
qt-hmi [--configpath <file>] [-platform <qpa>]
```

Parameters come from `/etc/qt-hmi.conf`, then the environment, then the command line, each
overriding the one before; `--help` lists them. The QPA platform is whatever the session
provides — nothing here selects one. `fullscreen` decides whether the window asks for the
whole screen; it ships on, and a local run wants it off.

## Where this runs

A Raspberry Pi 5 on Raspberry Pi OS Desktop, autostarted inside the board's session and
installed with `apt` from this Gitea's Debian registry:

```sh
curl -fsSL https://git.example.com/api/packages/<REDACTED>/debian/repository.key \
  | sudo tee /etc/apt/keyrings/gitea-<REDACTED>.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/gitea-<REDACTED>.asc] \
https://git.example.com/api/packages/<REDACTED>/debian trixie main" \
  | sudo tee /etc/apt/sources.list.d/qt-hmi.list
```

`main` there is the channel: it and `testing` are two components of the one repository, so a
board takes whichever it names. An update is `apt upgrade` and a rollback is
`apt install qt-hmi=<older>`. What to do after the install, and what the package depends on
that nothing can see, are in [docs/packaging.md](docs/packaging.md); what has to be true of
the board's session before any of it shows is [docs/session.md](docs/session.md).

The **qt-hmi-buildroot** repository also consumes this tree as a git submodule, building it into
a purpose-built Buildroot image for the same board. Everything about that image is
documented there.

Nothing here depends on either. The application builds and runs on any Linux machine with
Qt 6.

## Licence

MIT.
