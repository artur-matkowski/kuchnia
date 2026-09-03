"""The settings a person changes from the web page, and the file they live in.

Everything that is not a secret is here rather than in the environment, because the
environment cannot be edited without recreating the container and this service is one a
person opens a page on. `.env` holds VNC_PASSWORD and nothing else.

Values are read live: the poller re-reads its interval every cycle and the session re-reads
authuser on every request, so a change takes effect without a restart.
"""

import json
import logging
import os
import tempfile
import threading

LOG = logging.getLogger("location.config")

# name -> (default, kind, help). `kind` is what the form renders and what validate() checks.
FIELDS = {
    "authuser": (
        "0", "text",
        "Which signed-in Google account, as its index in the browser. Wrong here is the one "
        "setting that fails by looking right: another account answers with a perfectly valid "
        "roster of nobody.",
    ),
    "poll_interval_s": (
        30, "int",
        "Seconds between reads of the location RPC.",
    ),
    "rotate_interval_s": (
        600, "int",
        "Fallback seconds between cookie refreshes. Google states the real interval in its "
        "answer and that is what gets used; this is only what stands in when it does not.",
    ),
    "http_timeout_s": (
        20, "int",
        "Seconds any one request to Google may take.",
    ),
    "stale_after_s": (
        300, "int",
        "How old the last SUCCESSFUL poll may be before /v1/people starts refusing. Not how "
        "old a person's fix may be - a phone that slept is this service working.",
    ),
    "log_level": (
        "INFO", "text",
        "DEBUG, INFO, WARNING or ERROR.",
    ),
    "tile_upstream": (
        "https://tile.openstreetmap.org", "text",
        "Where /tiles fetches from on a cache miss. No trailing slash.",
    ),
    "tile_ttl_days": (
        30, "int",
        "How long a cached tile is served before it is fetched again.",
    ),
    "tile_user_agent": (
        "kuchnia-tiles/1.0 "
        "(+https://github.com/artur-matkowski/kuchnia; kitchen panel)", "text",
        "Sent upstream. The OpenStreetMap tile policy rejects a client that does not identify "
        "itself, and this proxy is the only client it ever sees - the panel's own User-Agent "
        "never reaches it.",
    ),
}

DEFAULTS = {name: spec[0] for name, spec in FIELDS.items()}

LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR")


class Config:
    def __init__(self, path):
        self._path = path
        self._lock = threading.Lock()
        self._values = dict(DEFAULTS)
        self._load()

    def __getitem__(self, name):
        with self._lock:
            return self._values[name]

    def all(self):
        with self._lock:
            return dict(self._values)

    def _load(self):
        try:
            with open(self._path, encoding="utf-8") as handle:
                stored = json.load(handle)
        except FileNotFoundError:
            LOG.info("no %s yet - running on the defaults", self._path)
            return
        except (OSError, json.JSONDecodeError) as error:
            LOG.error("%s is unreadable (%s) - running on the defaults", self._path, error)
            return

        kept, errors = validate({k: v for k, v in stored.items() if k in DEFAULTS})
        for message in errors:
            LOG.error("%s: %s - that field stays at its default", self._path, message)
        self._values.update(kept)
        self.apply_log_level()

    def update(self, incoming):
        """Validate, store and persist. Answers the list of complaints; [] means saved."""
        kept, errors = validate(incoming)
        if errors:
            return errors

        with self._lock:
            self._values.update(kept)
            snapshot = dict(self._values)

        # Atomic, and in the same directory so the rename cannot cross a filesystem.
        directory = os.path.dirname(self._path) or "."
        handle = tempfile.NamedTemporaryFile(
            "w", dir=directory, prefix=".config-", suffix=".json",
            delete=False, encoding="utf-8")
        try:
            json.dump(snapshot, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.close()
            os.chmod(handle.name, 0o600)
            os.replace(handle.name, self._path)
        except OSError:
            os.unlink(handle.name)
            raise

        self.apply_log_level()
        return []

    def apply_log_level(self):
        logging.getLogger("location").setLevel(self["log_level"])


def validate(incoming):
    """(accepted values, complaints). A field that does not validate is simply not accepted."""
    kept = {}
    errors = []

    for name, raw in incoming.items():
        if name not in FIELDS:
            errors.append(f"no such setting: {name}")
            continue

        _, kind, _ = FIELDS[name]
        value = raw.strip() if isinstance(raw, str) else raw

        if kind == "int":
            try:
                value = int(value)
            except (TypeError, ValueError):
                errors.append(f"{name} must be a whole number, not {raw!r}")
                continue
            if value < 1:
                errors.append(f"{name} must be at least 1, not {value}")
                continue

        if name == "log_level":
            value = str(value).upper()
            if value not in LEVELS:
                errors.append(f"log_level must be one of {', '.join(LEVELS)}, not {raw!r}")
                continue

        if name == "authuser" and not str(value).isdigit():
            errors.append(f"authuser is an account index, so it is digits - not {raw!r}")
            continue

        if name == "tile_upstream":
            value = str(value).rstrip("/")
            if not value.startswith(("http://", "https://")):
                errors.append(f"tile_upstream must be an absolute http(s) URL, not {raw!r}")
                continue

        if kind == "text" and not str(value):
            errors.append(f"{name} cannot be empty")
            continue

        kept[name] = value

    return kept, errors
