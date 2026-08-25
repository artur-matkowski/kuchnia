"""The map's tiles, cached on disk, so the board has one host to reach and not two.

The panel's Qt osm plugin appends "{z}/{x}/{y}.png" to map-tile-url, so this answers exactly
that shape and 404s everything else.
"""

import logging
import os
import re
import tempfile
import threading
import time
import urllib.error
import urllib.request

LOG = logging.getLogger("location.tiles")

TILE_PATH = re.compile(r"^/tiles/(\d{1,2})/(\d{1,7})/(\d{1,7})\.png$")

# Above this the pyramid is finer than anything the panel frames, and an open proxy over an
# unbounded z is a way to be banned from a free tile server.
MAX_ZOOM = 19


class Tiles:
    def __init__(self, config, cache_dir, lanes=64):
        self._config = config
        self._dir = cache_dir
        # Re-framing the viewport asks for a screenful of tiles at once, and asks again the
        # moment anybody moves. Without this, every request for one tile that is not cached
        # yet is its own fetch. A fixed set of lanes rather than a lock per tile: the dict
        # would grow for the life of the process, and a collision only means two unrelated
        # tiles take turns.
        self._lanes = [threading.Lock() for _ in range(lanes)]

    def match(self, path):
        """(z, x, y) for a well-formed tile path, or None. Not an error: web.py 404s it."""
        found = TILE_PATH.match(path)
        if not found:
            return None

        z, x, y = (int(part) for part in found.groups())
        if z > MAX_ZOOM:
            return None
        # Outside the pyramid the upstream answers 404 anyway; refusing here keeps a typo out
        # of somebody else's logs and out of this cache.
        if x >= (1 << z) or y >= (1 << z):
            return None
        return z, x, y

    def get(self, z, x, y):
        """(status, body, cache status). Never raises. A failed fetch falls back to disk."""
        path = os.path.join(self._dir, str(z), str(x), f"{y}.png")

        body = self._read_fresh(path)
        if body is not None:
            return 200, body, "HIT"

        with self._lanes[hash((z, x, y)) % len(self._lanes)]:
            # Somebody else may have fetched it while this request waited for the lane.
            body = self._read_fresh(path)
            if body is not None:
                return 200, body, "HIT"

            url = f"{self._config['tile_upstream']}/{z}/{x}/{y}.png"
            request = urllib.request.Request(
                url, headers={"User-Agent": self._config["tile_user_agent"]})
            try:
                with urllib.request.urlopen(request, timeout=20) as response:
                    body = response.read()
            except urllib.error.HTTPError as error:
                LOG.warning("%s answered HTTP %d", url, error.code)
                # An upstream 404 is a tile that does not exist at that zoom, and nothing on
                # disk can stand in for one.
                if error.code == 404:
                    return 404, b"", "MISS"
            except Exception as error:  # noqa: BLE001
                LOG.warning("%s failed: %s", url, error)
            else:
                self._store(path, body)
                return 200, body, "MISS"

            return self._stale(path)

    def _stale(self, path):
        """The expired tile, if there is one, because a 502 here outlives the blip that caused
        it by days - the panel never asks again. See docs/location.md."""
        body = self._read(path)
        if body is None:
            return 502, b"", "MISS"
        return 200, body, "STALE"

    def _read_fresh(self, path):
        """The cached tile while it is inside its TTL. None is absent OR expired."""
        try:
            age = time.time() - os.path.getmtime(path)
        except OSError:
            return None
        if age > self._config["tile_ttl_days"] * 86400:
            return None
        return self._read(path)

    def _read(self, path):
        """Whatever is on disk, however old."""
        try:
            with open(path, "rb") as handle:
                return handle.read()
        except OSError:
            return None

    def _store(self, path, body):
        directory = os.path.dirname(path)
        try:
            os.makedirs(directory, exist_ok=True)
            # Atomic, so a reader never sees half a PNG - and in the same directory, so the
            # rename cannot cross a filesystem.
            handle = tempfile.NamedTemporaryFile(
                "wb", dir=directory, prefix=".tile-", delete=False)
            handle.write(body)
            handle.close()
            os.replace(handle.name, path)
        except OSError as error:
            LOG.warning("could not cache %s: %s", path, error)
