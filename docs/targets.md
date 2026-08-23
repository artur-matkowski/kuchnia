# Two builds, and the host tools a Qt cross build needs

> Owns: scripts/build.sh
> See:  docs/app.md docs/packaging.md

`scripts/build.sh host` is a window on this desktop. The board's binary is the arm64 `.deb`,
cross-built against Debian's own libraries — [packaging](docs/packaging.md). Nothing here
carries a toolchain file: the desktop build uses the desktop's compiler and the package
build takes everything from `dh_auto_configure`.

**One build directory per build.** A CMake cache records the compiler it was configured
with. Pointing a second build at `build/host/` does not fail — it answers out of the wrong
cache, and the error that eventually surfaces names a link failure rather than a stale
configure. That is why the target is still spelled out on the command line for a script with
only one of them.

**A Qt cross build needs the host tools too.** `moc`, `rcc`, `qmlcachegen` and
`qmlimportscanner` run on the build machine, and no toolchain file names them — Debian's does
not know this is a Qt project. Without `QT_HOST_PATH` the configure step fails reporting that
it cannot find the `Qt6` package, which sends you looking at the libraries rather than at the
host tree.

**On Debian multiarch, `QT_HOST_PATH` alone is not enough.** Qt looks for the host package
under `${QT_HOST_PATH}/lib/cmake`, and Debian keeps it one directory deeper, under the build
machine's triplet. `QT_HOST_PATH=/usr` on its own therefore fails the same way naming nothing
does, and `debian/rules` passes `QT_HOST_PATH_CMAKE_DIR` beside it.
