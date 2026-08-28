#!/bin/bash
#
# Build the Debian package. Nothing here is CI-specific: the workflow runs this script
# with --here inside the builder image, and a developer runs it without arguments to get
# the same build in a throwaway container of the same image.
#
#     scripts/build-deb.sh                 in the builder image, into dist/
#     scripts/build-deb.sh --here          in this environment, installing what it needs
#     scripts/build-deb.sh --here --version 1.0.42~testing
#     scripts/build-deb.sh --deps-only     install the build dependencies and stop
#
# --here installs packages and is meant for a container. Running it on a workstation
# changes that workstation. --version rewrites debian/changelog, which for the default
# path is a bind mount of the working tree.
#
# The build dependencies are never listed here: apt-get build-dep reads debian/control, so
# the package list has one home and cannot drift from what the package declares.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The builder image names a registry, and this tree is public, so it is not written down
# here. CI passes the same value from its BUILDER_IMAGE variable - see docs/ci.md.
IMAGE="${KUCHNIA_BUILDER_IMAGE:-}"
HOST_ARCH=arm64
# $HOST_ARCH's toolchain prefix, spelled out because dpkg-architecture is itself one of the
# packages the check below runs before anything is installed.
HOST_GNU=aarch64-linux-gnu

die()   { echo "error: $*" >&2; exit 1; }
usage() { sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }

HERE=0
DEPS_ONLY=0
VERSION=""

while [ $# -gt 0 ]; do
	case "$1" in
		--here)       HERE=1 ;;
		--deps-only)  HERE=1; DEPS_ONLY=1 ;;
		--version)    shift; [ $# -gt 0 ] || die "--version needs a value"; VERSION=$1 ;;
		-h|--help)    usage ;;
		*)            echo "error: unknown argument $1" >&2; usage ;;
	esac
	shift
done

if [ "$HERE" = 0 ]; then
	[ -n "$IMAGE" ] || die "set KUCHNIA_BUILDER_IMAGE to the builder image, or use --here"
	command -v docker >/dev/null || die "no docker - use --here inside a $IMAGE environment"
	INNER=(bash scripts/build-deb.sh --here)
	if [ -n "$VERSION" ]; then
		INNER+=(--version "$VERSION")
	fi
	echo "==> $IMAGE"
	exec docker run --rm -v "$ROOT":/src -w /src "$IMAGE" "${INNER[@]}"
fi

[ -r /etc/debian_version ] || die "--here wants a Debian environment; this is not one"

export DEBIAN_FRONTEND=noninteractive

# The builder image already carries all of this, because scripts/builder.Dockerfile bakes it
# in by running this same step. dpkg-checkbuilddeps reads the debian/control that
# apt-get build-dep reads, so an image that has fallen behind the package installs the delta
# and says so in the log rather than building against a set nobody declared. See docs/ci.md.
build_deps_present() {
	command -v dpkg-checkbuilddeps >/dev/null || return 1
	command -v "$HOST_GNU-g++"     >/dev/null || return 1
	(cd "$ROOT" && dpkg-checkbuilddeps -a "$HOST_ARCH" >/dev/null 2>&1)
}

echo "==> dependencies"
if build_deps_present; then
	echo "    satisfied by this environment"
else
	dpkg --add-architecture "$HOST_ARCH"
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends \
		build-essential devscripts dpkg-dev git "crossbuild-essential-$HOST_ARCH"
	apt-get build-dep -y -qq --no-install-recommends \
		--host-architecture "$HOST_ARCH" "$ROOT"
fi

if [ "$DEPS_ONLY" = 1 ]; then
	exit 0
fi

# dpkg-buildpackage takes the version from the changelog and nowhere else. --force-bad-version
# is what lets CI hand it a version older than the entry already there, which happens on any
# branch build that runs after a higher-numbered one.
if [ -n "$VERSION" ]; then
	echo "==> version $VERSION"
	cd "$ROOT"
	EMAIL="ci@example.com" DEBFULLNAME="Gitea Actions" \
		dch --newversion "$VERSION" --distribution trixie --force-bad-version \
		    --controlmaint "Build from $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

echo "==> build $HOST_ARCH"
cd "$ROOT"
# -b is a binary-only build, and noautodbgsym keeps the second package it would otherwise
# produce out of the way - only one artifact is ever published.
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-} noautodbgsym" \
	dpkg-buildpackage --host-arch "$HOST_ARCH" -us -uc -b

# dpkg-buildpackage writes beside the source tree, which for a bind mount is outside it.
mkdir -p "$ROOT/dist"
mv "$ROOT"/../kuchnia_*_"$HOST_ARCH".deb "$ROOT/dist/"
rm -f "$ROOT"/../kuchnia_*.buildinfo "$ROOT"/../kuchnia_*.changes

# Everything below is a bind mount written by root. Left alone the developer gets a tree
# they cannot delete, so the build tree goes and the artifact takes the tree's ownership.
# dh_auto_clean derives the build directory from the host architecture, so a bare
# `debian/rules clean` goes looking for the build machine's and leaves this one behind.
dpkg-architecture --host-arch "$HOST_ARCH" -c debian/rules clean >/dev/null
chown --reference="$ROOT" "$ROOT/dist" "$ROOT/dist"/*.deb debian/changelog

echo "==> $ROOT/dist"
ls -la "$ROOT/dist"
