"""Wiring. One process: the poller thread, the tile cache and the HTTP front.

Paths are absolute and fixed because they are the container's, and each is a bind mount from
services/ in the repository so that cleaning up is rm -rf and nothing else.
"""

import logging
import os
import sys

from .config import Config
from .google import Session
from .roster import Poller, Roster
from .signin import SignIn
from .tiles import Tiles
from .web import serve

CONFIG_FILE = "/data/config.json"
COOKIES_FILE = "/data/cookies.txt"
PROFILE_DIR = "/profile"
CACHE_DIR = "/cache"
SUPERVISOR_URL = "unix:///run/supervisor.sock"


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stdout,
    )

    # The one secret, and the only thing that is not editable from the page. entrypoint.sh
    # refuses to start without it, so reaching here without one means supervisord was run by
    # hand - which is still worth refusing rather than serving the screen to anybody.
    password = os.environ.get("VNC_PASSWORD", "")
    if not password:
        raise SystemExit("VNC_PASSWORD is unset - see services/.env.example")

    port = int(os.environ.get("LISTEN_PORT", "8080"))

    config = Config(CONFIG_FILE)
    session = Session(config, COOKIES_FILE)
    roster = Roster(config)
    tiles = Tiles(config, CACHE_DIR)
    signin = SignIn(SUPERVISOR_URL, PROFILE_DIR, COOKIES_FILE)

    poller = Poller(session, roster, config)
    poller.start()
    serve(port, password, config, roster, poller, tiles, signin)


if __name__ == "__main__":
    main()
