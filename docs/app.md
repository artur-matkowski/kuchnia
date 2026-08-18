# The process

> Owns: src/main.cpp
> Owns: CMakeLists.txt
> See:  docs/qml.md docs/targets.md

A `QGuiApplication`, an engine, one QML module compiled into the binary. There is no C++
scene, no exported type and no backend seam — that is the split with the `drm-hmi`
repository, and adding one here is a decision, not a refactor.

**The engine does not exit on a QML error.** `loadFromModule()` returns `void` and a failed
load leaves a valid engine with no root object, which then runs the event loop forever. On a
board that is a live process painting nothing — the same symptom as a GPU that never bound.
The `objectCreationFailed` connection is the only thing turning that into an exit code.

**`URI QtHmi` is written twice** — in `qt_add_qml_module()` and in the `loadFromModule()`
call — and nothing checks that the two agree. A rename in one place builds cleanly and fails
at startup with "module QtHmi is not installed", which reads as a missing Qt install.

**The QML files are aliased into the module.** Without `QT_RESOURCE_ALIAS` each file keeps
its path relative to `CMakeLists.txt`, so the module's contents are named
`src/qml/Main.qml`. It resolves either way; the alias is what stops the module's public
shape from tracking where the sources happen to sit.

`QtQuick.Shapes` is imported by QML and named in no CMake target. It is part of
`qt6declarative`, so it is present whenever Quick is — but a Qt built without it fails at
startup and not at build time.
