"""What the last poll produced, why the one after it did not, and the thread that polls."""

import logging
import threading
import time

from .google import SessionExpired, UpstreamChanged

LOG = logging.getLogger("location.roster")


class Roster:
    def __init__(self, config):
        self._config = config
        self._lock = threading.Lock()
        self._people = None
        self._fetched_at = 0.0
        self._without_fix = 0
        self._error = None

    def succeed(self, people, without_fix):
        with self._lock:
            self._people = people
            self._fetched_at = time.time()
            self._without_fix = without_fix
            self._error = None

    def fail(self, reason):
        with self._lock:
            self._error = reason

    def snapshot(self):
        with self._lock:
            age = time.time() - self._fetched_at if self._people is not None else None
            return self._people, age, self._without_fix, self._error

    def serve(self):
        """(status, body) for /v1/people.

        A dead session must never leave here as {"people": []}. An empty roster is a real
        answer - nobody is sharing right now - and nothing on the panel can tell the two apart
        from the body alone, so a failure is a status code and a named reason instead.
        """
        people, age, without_fix, error = self.snapshot()

        if people is None:
            return 503, {"error": error or "no poll has completed yet"}
        if age > self._config["stale_after_s"]:
            return 503, {
                "error": f"the last successful poll was {int(age)}s ago "
                         f"({error or 'no reason recorded'})"
            }

        body = {"people": people}
        if without_fix:
            body["without_fix"] = without_fix
        return 200, body

    def health(self):
        people, age, without_fix, error = self.snapshot()
        status, _ = self.serve()
        return status, {
            "status": "ok" if status == 200 else "failing",
            "people": len(people) if people is not None else None,
            "without_fix": without_fix,
            "age_s": int(age) if age is not None else None,
            "last_error": error,
        }


class Poller(threading.Thread):
    def __init__(self, session, roster, config):
        super().__init__(name="poller", daemon=True)
        self._session = session
        self._roster = roster
        self._config = config
        self._wake = threading.Event()

    def wake(self):
        """Cut the current wait short - the settings page changed something.

        Without this, raising or lowering poll_interval_s does nothing until the interval
        that is already being slept runs out. Set it to an hour by accident and the page
        looks broken for an hour.
        """
        self._wake.set()

    def run(self):
        next_rotation = 0.0
        while True:
            if time.time() >= next_rotation:
                next_rotation = time.time() + self._rotate()

            try:
                people, without_fix = self._session.read_roster()
                self._roster.succeed(people, without_fix)
                LOG.info("%d sharing, %d without a fix", len(people), without_fix)
            except SessionExpired as error:
                # The one failure a restart does not fix, so it is logged at the level that
                # gets read rather than folded in with a timeout.
                LOG.error("session expired: %s", error)
                self._roster.fail(str(error))
            except UpstreamChanged as error:
                LOG.error("the RPC changed shape: %s", error)
                self._roster.fail(str(error))
            except Exception as error:  # noqa: BLE001 - one bad poll must not end the loop
                LOG.warning("poll failed: %s", error)
                self._roster.fail(f"{type(error).__name__}: {error}")

            # Re-read every cycle: the interval is editable from the web page, and a value
            # captured at startup would need a restart nobody would think to do.
            self._wake.wait(self._config["poll_interval_s"])
            self._wake.clear()

    def _rotate(self):
        try:
            interval = self._session.rotate()
            LOG.info("next cookie rotation in %ds", interval)
            return interval
        except Exception as error:  # noqa: BLE001
            LOG.warning("cookie rotation failed: %s", error)
            return self._config["rotate_interval_s"]
