# The process

> Owns: src/main.cpp
> Owns: CMakeLists.txt
> See:  docs/scene.md docs/state.md docs/targets.md docs/integrations.md docs/media.md docs/radio.md

A `QGuiApplication`, an engine, one QML module compiled into the binary, a bundled font, and
a set of network clients started beside it. The seam between the clients and the scene is
[state](docs/state.md); how the clients themselves work is
[integrations](docs/integrations.md).

**Everything Qt says is routed into `applog`.** `qInstallMessageHandler` goes in immediately
after `applog::init()` and before `QGuiApplication`, under the `QT` topic. Without it QML
binding warnings and the media backend's complaints go to stderr, which on the board is not
the file anybody reads — invisible exactly when the screen is wrong.

**libav does not come through that handler, and a filter written there is dead code that
reads as live.** Qt's ffmpeg backend installs an `av_log` callback of its own, and unless
`QT_FFMPEG_DEBUG` is set that callback forwards to `av_log_default_callback` — libavutil
formats the line and writes it to stderr itself, and `qInstallMessageHandler` never sees it.
A `[swscaler @ 0x…]` prefix is the tell: nothing in Qt's own logging puts one there.

`routeLibavLog()` therefore takes `av_log` over, and three things about it are load-bearing:

* **It runs after a `QMediaPlayer` exists.** Constructing one loads the media backend, which
  is both what brings `libavutil` into the process and when Qt installs the callback this one
  replaces. Earlier is a lookup that finds nothing, then a callback Qt overwrites.
* **The symbols come out of the link map, not `RTLD_DEFAULT`.** Qt dlopens plugins into a
  local scope, so `dlsym(RTLD_DEFAULT, …)` answers null on a process that plainly has ffmpeg
  in it. `dl_iterate_phdr` names the object and `dlopen` on that path hands back the copy
  already loaded.
* **`av_vlog` does not filter by level.** That check lives in the default callback, which is
  exactly what was replaced — so the replacement has to make it. Without `av_log_get_level()`
  every decoder debug line, one per NAL, is formatted before `applog` discards it.

One line is dropped by name, `deprecated pixel format used`. The cameras encode full-range
H.264, so the decoder hands Qt `yuvj420p`, and Qt frees the `SwsContext` after every frame —
libswscale warns per frame rather than once per stream, and buries the log. Nothing here
chooses either. Everything else libav says is kept at its own level, and `QT_FFMPEG_DEBUG`
still works, now landing in `applog` with the rest.

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

## What stops the screen, and how to tell which

Input is on the GUI thread, and in Qt's threaded render loop that thread blocks on the render
thread every frame — so anything slow in either reads identically from outside: the panel stops
answering the keyboard. `Main.qml`'s `guiStall` timer ticks on the GUI thread and logs how late
a tick was, so a freeze leaves a number behind instead of nothing.

**The scene can be drawn on the CPU without a word.** The Buildroot image carried no software
rasteriser, so a `v3d` that did not bind was a black screen and an obvious fault. Raspberry Pi
OS ships llvmpipe and Qt simply uses it: the panel paints, slowly, and stalls under load.
`reportRenderer()` runs on the render thread once the scene graph is up and says so at error
level, because nothing else in the process ever will.

**`QMediaPlayer::setSource()` is not a setter.** Qt's ffmpeg backend opens the media on
`QThreadPool::globalInstance()`, waits for that task on the calling thread, and runs a
not-yet-started open inline. So the pool is sized here against the number of players — one per
core by default, four on the board against five cameras and the radio — and the scene never
assigns `source` while `mediaStatus` is `LoadingMedia`: [media](docs/media.md),
[radio](docs/radio.md). The wait measures about a millisecond; the inline open costs seconds.

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
the radio's remembered station goes through — see [radio](docs/radio.md). Without them
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
