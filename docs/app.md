# The process

> Owns: src/main.cpp
> Owns: CMakeLists.txt
> See:  docs/scene.md docs/state.md docs/targets.md docs/integrations.md

A `QGuiApplication`, an engine, one QML module compiled into the binary, a bundled font, and
a set of network clients started beside it. The seam between the clients and the scene is
[state](docs/state.md); how the clients themselves work is
[integrations](docs/integrations.md).

**Everything Qt says is routed into `applog`.** `qInstallMessageHandler` goes in immediately
after `applog::init()` and before `QGuiApplication`, under the `QT` topic. Without it QML
binding warnings, the media backend's complaints and libav's lines under them go to stderr,
which on the board is not the file anybody reads — invisible exactly when the screen is
wrong. The handler drops one line, `deprecated pixel format used`: the cameras deliver
`yuvj420p` and libswscale says so once per scaler context, per camera, per reconnect, and
nothing here chooses the decoder's output format. The filter is that narrow on purpose —
silencing the category would take real ffmpeg errors with it.

**Order in `main()` is load-bearing, and so is declaration order.** Logging is up first
because reading the settings logs; the settings are read before `QGuiApplication` so that
`--help` and a malformed value answer without a display. Then, in this order:

1. `AppState` — the objects the scene binds to.
2. `Integrations` — the worker threads, holding callbacks that point at those objects.
3. `QQmlApplicationEngine`, `registerSingletons()`, `loadFromModule()`.

Destruction reverses it, which is the point: the engine goes first, then the threads are
joined, and only then do the objects their callbacks point at go away. Move `AppState` below
`Integrations` and shutdown becomes a worker queueing onto freed memory — intermittently,
and only on exit.

**`registerSingletons()` must run before the load.** A singleton registered after the scene
is built is a name QML has already failed to resolve, and the failure is a binding that
evaluates to `undefined` rather than an error. Queued calls that arrive before `exec()` are
harmless; they sit in the event queue.

**The engine does not exit on a QML error.** `loadFromModule()` returns `void` and a failed
load leaves a valid engine with no root object, which then runs the event loop forever. On a
board that is a live process painting nothing — the same symptom as a GPU that never bound.
The `objectCreationFailed` connection is the only thing turning that into an exit code.

**`URI QtHmi` is written three times** — in `qt_add_qml_module()`, in the `loadFromModule()`
call, and in every `qmlRegisterSingletonInstance()` in `AppState.cpp` — and nothing checks
that they agree. A rename in one place builds cleanly and fails at startup with "module
QtHmi is not installed" or "Gate is not a type", either of which reads as a broken Qt.

## The font is in the binary

The target has no fonts and no fontconfig. A `Text` item there draws nothing at all and says
nothing about it, so every label, axis and reading is simply absent on a screen that is
otherwise working — and a host build masks it completely, because the desktop has fonts.

`loadBundledFont()` therefore installs Liberation Sans out of `:/fonts/` and checks the
result: `addApplicationFont` answers `-1` for a missing resource path and for a corrupt face
alike, and both produce the same blank screen. The resource lives in its own
`qt_add_resources()` call rather than in the QML module's `RESOURCES`, which would put it
under `:/qt/qml/QtHmi/` and break the path `main.cpp` opens.

`QCoreApplication::setOrganizationName`/`setApplicationName` are set for `QSettings`, which
the radio's remembered station goes through — see [media](docs/media.md). Without them
`QSettings` refuses to open a file and says so only as a warning.

## CMake

**The QML files are aliased into the module.** Without `QT_RESOURCE_ALIAS` each file keeps
its path relative to `CMakeLists.txt`, so the module's contents are named
`src/qml/Main.qml`. It resolves either way; the alias is what stops the module's public
shape from tracking where the sources happen to sit.

**`Theme.qml` needs `QT_QML_SINGLETON_TYPE` as well as its `pragma Singleton`.** With only
the pragma the generated `qmldir` does not declare it and every `Theme.` in the scene
evaluates to `undefined` — an unstyled screen, not an error.

`Qt6::Multimedia` links, but the `QtMultimedia` QML import and the backend that decodes
anything are both loaded at runtime. A build that links fine still plays nothing on an image
missing either; [media](docs/media.md) lists what the image has to carry.

`QtQuick.Shapes` and `QtQuick.Layouts` are imported by QML and named in no CMake target.
Both are part of `qt6declarative`, so they are present whenever Quick is — but a Qt built
without them fails at startup and not at build time.
