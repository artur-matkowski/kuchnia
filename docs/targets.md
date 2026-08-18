# Two targets

> Owns: scripts/build.sh
> Owns: scripts/toolchain.cmake.example
> See:  docs/app.md

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
