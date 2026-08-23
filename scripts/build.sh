#!/bin/bash
#
# Build the application into build/host/ rather than into the source tree.
#
#     scripts/build.sh host
#     scripts/build.sh host --clean
#     scripts/build.sh host --run
#
# A window on this desktop, and nothing else. The board's binary is the arm64 package -
# scripts/build-deb.sh, which cross-builds against Debian's own libraries in a container.
# The target is still named and still gets its own build directory: a CMake cache records
# the compiler it was configured with, and a second build sharing this one's directory
# would answer every later question out of the first one's cache.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '3,7p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }

TARGET=""
CLEAN=0
RUN=0

for arg in "$@"; do
	case "$arg" in
		host)       TARGET=$arg ;;
		--clean)    CLEAN=1 ;;
		--run)      RUN=1 ;;
		-h|--help)  usage ;;
		*)          echo "error: unknown argument $arg" >&2; usage ;;
	esac
done
[ -n "$TARGET" ] || usage

OUT="$ROOT/build/$TARGET"

if [ "$CLEAN" = 1 ]; then
	echo "==> clean $OUT"
	rm -rf "$OUT"
fi

echo "==> configure $TARGET"
cmake -S "$ROOT" -B "$OUT" -DCMAKE_BUILD_TYPE=Release

echo "==> build $TARGET"
cmake --build "$OUT" --parallel "$(nproc)"

echo "==> $OUT/qt-hmi"

if [ "$RUN" = 1 ]; then
	exec "$OUT/qt-hmi"
fi
