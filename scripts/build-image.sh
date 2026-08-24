#!/bin/bash
#
# Build and publish the image the package is built in.
#
#     scripts/build-image.sh               build and push
#     scripts/build-image.sh --no-push     build only
#
# Nothing builds this image on its own: run it when debian/control changes, and when the
# base is worth refreshing. A build against an image that has fallen behind still produces
# the right package - build-deb.sh installs the delta - it just pays for it. See docs/ci.md.
#
# Pushing wants a prior `docker login git.example.com` with a token carrying write:package.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=git.example.com/<REDACTED>/kuchnia-builder:trixie

die()   { echo "error: $*" >&2; exit 1; }
usage() { sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }

PUSH=1

while [ $# -gt 0 ]; do
	case "$1" in
		--no-push)  PUSH=0 ;;
		-h|--help)  usage ;;
		*)          echo "error: unknown argument $1" >&2; usage ;;
	esac
	shift
done

command -v docker >/dev/null || die "no docker"

echo "==> build $IMAGE"
docker build --pull -f "$ROOT/scripts/builder.Dockerfile" -t "$IMAGE" "$ROOT"

if [ "$PUSH" = 1 ]; then
	echo "==> push $IMAGE"
	docker push "$IMAGE"
fi

echo "==> $IMAGE"
docker image inspect "$IMAGE" --format '{{.Id}} {{.Size}} bytes'
