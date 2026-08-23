#!/bin/bash
#
# Build the application into build/<target>/ rather than into the source tree.
#
#     scripts/build.sh host             a window on this desktop
#     scripts/build.sh board            the board's binary - cross-compiled against a sysroot
#     scripts/build.sh board --clean
#     scripts/build.sh host --run
#
# One directory per target, and that is the point of having two. A CMake cache records the
# compiler it was configured with; pointing a second target at the same directory does not
# fail, it answers every later question out of the first target's cache.
#
# The toolchain belongs to the caller, who writes it in scripts/toolchain.cmake - copied
# from scripts/toolchain.cmake.example and never committed. This script picks a target and
# runs cmake. Where a cross compiler comes from is the business of whoever consumes this
# repository, and nothing here may learn it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die()   { echo "error: $*" >&2; exit 1; }
usage() { sed -n '3,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }

TARGET=""
CLEAN=0
RUN=0

for arg in "$@"; do
	case "$arg" in
		host|board) [ -z "$TARGET" ] || die "two targets given: $TARGET and $arg"
		            TARGET=$arg ;;
		--clean)    CLEAN=1 ;;
		--run)      RUN=1 ;;
		-h|--help)  usage ;;
		*)          echo "error: unknown argument $arg" >&2; usage ;;
	esac
done
[ -n "$TARGET" ] || usage

OUT="$ROOT/build/$TARGET"

CMAKE_ARGS=(-S "$ROOT" -B "$OUT" -DCMAKE_BUILD_TYPE=Release)

if [ "$TARGET" = board ]; then
	TOOLCHAIN="$ROOT/scripts/toolchain.cmake"
	[ -f "$TOOLCHAIN" ] ||
		die "no $TOOLCHAIN - copy scripts/toolchain.cmake.example and edit it"
	CMAKE_ARGS+=(-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN")
fi

if [ "$CLEAN" = 1 ]; then
	echo "==> clean $OUT"
	rm -rf "$OUT"
fi

echo "==> configure $TARGET"
cmake "${CMAKE_ARGS[@]}"

echo "==> build $TARGET"
cmake --build "$OUT" --parallel "$(nproc)"

echo "==> $OUT/qt-hmi"

if [ "$RUN" = 1 ]; then
	[ "$TARGET" = host ] || die "--run builds for this machine only; use host"
	exec "$OUT/qt-hmi"
fi
