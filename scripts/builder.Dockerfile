# The environment the package is built in - by CI on every push, and by
# scripts/build-deb.sh with no arguments. Built and published by scripts/build-image.sh.
# See docs/ci.md.
FROM debian:trixie

# The package list has one home, and this is not it: --deps-only runs the same step
# build-deb.sh runs, which reads debian/control. An image cannot declare a set the package
# does not.
COPY debian /src/debian
COPY scripts/build-deb.sh /src/scripts/
WORKDIR /src
RUN bash scripts/build-deb.sh --deps-only

# git and ca-certificates are the workflow's clone and curl is its upload; none of the three
# is a build dependency. ccache is the other half of what makes a run cheap - and the test is
# there because a missing symlink is not an error, it is a compiler that is simply not ccache.
RUN apt-get install -y -qq --no-install-recommends git ca-certificates curl ccache \
 && update-ccache-symlinks \
 && test -x /usr/lib/ccache/aarch64-linux-gnu-g++ \
 && rm -rf /var/lib/apt/lists/*

# dh_auto_configure names the compiler unqualified, so this is the whole of the ccache
# wiring: CMake resolves aarch64-linux-gnu-g++ through PATH onto the symlink above. Nothing
# in CMakeLists.txt or debian/rules knows that ccache exists.
ENV PATH=/usr/lib/ccache:$PATH
ENV CCACHE_DIR=/ccache
ENV CCACHE_MAXSIZE=2G
