# Two targets, and two ways to cross a compiler

> Owns: scripts/build.sh
> Owns: scripts/toolchain.cmake.example
> Owns: cmake/FindPoco.cmake
> See:  docs/app.md docs/integrations.md docs/packaging.md

`host` is a window on a desktop, `board` is the cross build against a Buildroot sysroot.
Both are plain CMake, and both are `scripts/build.sh`. The package the board actually
installs is cross-built a third way, against Debian's own arm64 libraries, and that build
belongs to [docs/packaging.md](docs/packaging.md) — what the two share is below.

**One build directory per target.** A CMake cache records the compiler it was configured
with. Pointing the second target at the first one's directory does not fail — it silently
answers out of the wrong cache, and the error that eventually surfaces names a link failure
rather than a stale configure.

**A Qt cross build needs the host tools too.** `moc`, `rcc`, `qmlcachegen` and
`qmlimportscanner` run on the build machine, and no toolchain file names them — neither
Buildroot's nor Debian's knows this is a Qt project. Without `QT_HOST_PATH` the configure
step fails reporting that it cannot find the `Qt6` package, which sends you looking at the
sysroot rather than at the host tree.

**On Debian multiarch, `QT_HOST_PATH` alone is not enough.** Qt looks for the host package
under `${QT_HOST_PATH}/lib/cmake`, and Debian keeps it one directory deeper, under the build
machine's triplet. `QT_HOST_PATH=/usr` on its own therefore fails the same way naming
nothing does, and `debian/rules` passes `QT_HOST_PATH_CMAKE_DIR` beside it.

`scripts/toolchain.cmake` is this machine's and is never committed. The image's build copies
this tree as it stands, so anything left in it travels.

## Finding the dependencies twice over

The two targets get Poco from builds with different install steps, and only one of them
writes a CMake package config. A desktop's Poco is built with CMake and ships
`PocoConfig.cmake`; a Buildroot sysroot's is built with Poco's classic configure/make, whose
install target copies headers and `libPoco*` and stops — `qt-hmi-buildroot/docs/build-pipeline.md`.
`cmake/FindPoco.cmake` is what makes the two look alike, and `find_package`'s basic
signature tries MODULE before CONFIG, so it wins on the desktop too. That is deliberate:
a discovery path exercised on only one target is a discovery path nobody tests.

**pkg-config ignores the sysroot.** `CMAKE_SYSROOT` constrains `find_library` and
`find_path` and has no effect on `pkg_check_modules`, which keeps its own search path.
Buildroot's package infrastructure exports `PKG_CONFIG_LIBDIR` and `scripts/build.sh board`
runs outside it, so `CMakeLists.txt` sets that variable itself whenever it is cross
compiling. Without it pkg-config reads the build machine's `.pc` files and the sysroot is
then pasted onto their `-I` and `-L` — which lands on real directories often enough to
configure, link, and produce a board binary carrying a desktop library's metadata.

That guard is written `CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT`, and the second half is what
keeps it out of the Debian cross build's way. Debian has no sysroot — the arm64 libraries
sit beside the build machine's under one root — so there is nothing to prefix, and
`dh_auto_configure` hands CMake a `PKG_CONFIG_EXECUTABLE` pointing at the host triplet's
wrapper instead. Dropping the `CMAKE_SYSROOT` half would make the guard fire there and send
pkg-config to the architecture-independent path, which finds a `.pc` file, configures, and
links the package against the build machine's `libpqxx` metadata.
