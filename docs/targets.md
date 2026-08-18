# Two targets

> Owns: scripts/build.sh
> Owns: scripts/toolchain.cmake.example
> Owns: cmake/FindPoco.cmake
> See:  docs/app.md docs/integrations.md

`host` is a window on a desktop, `board` is the cross build the image packages. Both are
plain CMake; there is no Buildroot vocabulary anywhere in this repository, and the image
repository owns the packaging — `qt-hmi-buildroot/docs/build-pipeline.md`.

**One build directory per target.** A CMake cache records the compiler it was configured
with. Pointing the second target at the first one's directory does not fail — it silently
answers out of the wrong cache, and the error that eventually surfaces names a link failure
rather than a stale configure.

**A Qt cross build needs the host tools too.** `moc`, `rcc`, `qmlcachegen` and
`qmlimportscanner` run on the build machine, and a Buildroot toolchain file names none of
them because Buildroot does not know this is a Qt project. Without `QT_HOST_PATH` the
configure step fails reporting that it cannot find the `Qt6` package, which sends you
looking at the sysroot rather than at the host tree.

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
