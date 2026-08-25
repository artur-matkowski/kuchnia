"""The private location-sharing RPC, and the cookie jar it is called with.

There is no official Google API for location sharing. This reads the RPC the Maps web client
uses, with a logged-in cookie jar, and it exists so that a credential which is full account
access lives on a server rather than on a kitchen wall panel.

Every field below is a fixed index into an undocumented array. Do not tidy them.
"""

import http.cookiejar
import json
import logging
import os
import re
import threading
import urllib.error
import urllib.parse
import urllib.request

LOG = logging.getLogger("location.google")

READ_URL = "https://www.google.com/maps/rpc/locationsharing/read"
ROTATE_URL = "https://accounts.google.com/RotateCookies"

# The viewport blob the Maps client sends. None of it selects who comes back - the cookie
# does that - but the RPC will not answer a request that has no `pb` at all, so it goes
# verbatim rather than trimmed to the parts that look meaningful.
READ_PB = (
    "!1m7!8m6!1m3!1i14!2i8413!3i5385!2i6!3x4095"
    "!2m3!1e0!2sm!3i407105169!3m7!2sen!5e1105!12m4"
    "!1e68!2m2!1sset!2sRoadmap!4e1!5m4!1e4!8m2!1e0!1e1"
    "!6m9!1e12!2i2!26m1!4b1!30m1!1f1.3953487873077393!39b1!44e1!50e0!23i4111425"
)

# A browser's. The RPC answers a client it does not recognise with a consent page instead of
# data, and that page is an HTTP 200.
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

# Every authenticated response carries this in front of the JSON so the body is not a valid
# script. Its absence is the only thing separating data from a login page - see read_roster.
XSSI_PREFIX = ")]}'"

SET_COOKIE_1PSIDTS = re.compile(r"__Secure-1PSIDTS=([^;]+)")

# The cookie that IS the session. A jar without it is an anonymous browser.
SESSION_COOKIE = "__Secure-1PSID"


class SessionExpired(Exception):
    """The cookie jar is no longer a signed-in Google session.

    Kept apart from every other failure because it is the only one a restart cannot fix: it
    needs a person to sign in again on the VNC screen and press Finish.
    """


class UpstreamChanged(Exception):
    """The RPC answered, and the answer is not the shape this file reads.

    Google moving a field is the expected way this breaks, and a moved field reads as a
    person standing somewhere else - which the map draws without complaint - so it is named
    here rather than left to surface as an IndexError with no context.
    """


class Session:
    """The cookie jar, and the two requests made with it.

    The jar is written back after every request, successful or not. Google mints a new
    __Secure-1PSIDTS on most authenticated calls, and a rotated cookie that is not persisted
    is a session that dies at the next restart - the failure this service exists to prevent.
    """

    def __init__(self, config, cookies_file):
        self._config = config
        self._path = cookies_file
        self._lock = threading.Lock()
        self._jar = None
        self._opener = None
        self._mtime = None
        self._load()

    @property
    def cookies_file(self):
        return self._path

    def _load(self):
        """Adopt whatever jar is on disk, or none at all.

        A missing or unusable jar is NOT fatal, which is the one place this service argues
        with the repository's fail-loud rule. The sign-in that writes this file runs inside
        this same container while the service is already up, so exiting here would mean the
        only way to renew the credential can never be reached. It answers 503 with a reason.
        """
        try:
            mtime = os.path.getmtime(self._path)
        except OSError:
            LOG.error("no cookie jar at %s yet - sign in on the web page and press Finish",
                      self._path)
            return

        jar = http.cookiejar.MozillaCookieJar(self._path)
        try:
            jar.load(ignore_discard=True, ignore_expires=True)
        except (OSError, http.cookiejar.LoadError) as error:
            # A file that is cookies but not in this format fails here, and the message
            # Python gives names neither the file nor the format it wanted. Remember the
            # mtime anyway, or every poll re-reads the same broken file and re-logs this.
            LOG.error('%s is not a Netscape cookie file (%s) - its first line must be '
                      '"# Netscape HTTP Cookie File"', self._path, error)
            self._mtime = mtime
            return

        names = {cookie.name for cookie in jar}
        if SESSION_COOKIE not in names:
            LOG.error("%s has no %s cookie (found: %s) - that one is the session, and without "
                      "it every request is anonymous",
                      self._path, SESSION_COOKIE, sorted(names) or "nothing")
            self._mtime = mtime
            return

        self._jar = jar
        self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        self._mtime = mtime
        LOG.info("loaded %d cookie(s) from %s", len(names), self._path)

    def _maybe_reload(self):
        """Pick up a jar the sign-in just harvested, without a restart.

        Compared by mtime rather than by content, and _save records the mtime it writes - so
        this fires for the harvest's write and not for the service's own rotation.
        """
        try:
            mtime = os.path.getmtime(self._path)
        except OSError:
            return
        if mtime != self._mtime:
            LOG.info("%s changed on disk - reloading the session", self._path)
            self._load()

    def _save(self):
        if self._jar is None:
            return
        # Both flags, or the two cookies that matter are dropped: the session cookie is
        # marked discard, and the rotated one arrives already close to its expiry.
        self._jar.save(ignore_discard=True, ignore_expires=True)
        try:
            self._mtime = os.path.getmtime(self._path)
        except OSError:
            self._mtime = None

    def _open(self, request):
        request.add_header("User-Agent", USER_AGENT)
        with self._lock:
            self._maybe_reload()
            if self._opener is None:
                raise SessionExpired(
                    f"there is no usable cookie jar at {self._path} - sign in as the burner "
                    "on the VNC screen and press Finish"
                )
            try:
                with self._opener.open(request, timeout=self._config["http_timeout_s"]) as r:
                    body = r.read().decode("utf-8", "replace")
                    headers = r.headers
            except urllib.error.HTTPError as error:
                if error.code in (401, 403):
                    raise SessionExpired(
                        f"Google refused the session with HTTP {error.code} - sign in again "
                        "on the VNC screen"
                    )
                raise
            finally:
                # Even a failed request can carry a Set-Cookie, and a rotation dropped on the
                # floor is the slow way to lose the session.
                self._save()
        return body, headers

    def read_roster(self):
        query = urllib.parse.urlencode({
            "authuser": self._config["authuser"],
            "hl": "en",
            "gl": "us",
            "pb": READ_PB,
        })
        body, _ = self._open(urllib.request.Request(f"{READ_URL}?{query}"))

        # A consent screen, a login page and an interstitial are all HTTP 200 with an HTML
        # body. The prefix is what separates "answered" from "answered with a page asking a
        # human to click something".
        if not body.startswith(XSSI_PREFIX):
            raise SessionExpired(
                "Google answered with a page instead of the location RPC - the cookie jar is "
                "no longer a signed-in session; sign in again on the VNC screen"
            )

        try:
            payload = json.loads(body[len(XSSI_PREFIX):])
        except json.JSONDecodeError as error:
            raise UpstreamChanged(f"the RPC body is not JSON behind its prefix ({error})")

        return parse(payload)

    def rotate(self):
        """Ask for a fresh __Secure-1PSIDTS; answer the seconds until the next one is due.

        Google declares the interval in the response - about ten minutes - so the keepalive
        follows what the server asks for rather than a number guessed here.
        """
        request = urllib.request.Request(
            ROTATE_URL,
            data=json.dumps([000, "-0000000000000000000"]).encode(),
            headers={
                "Content-Type": "application/json",
                "Referer": "https://accounts.google.com/",
            },
        )
        body, headers = self._open(request)

        if SET_COOKIE_1PSIDTS.search("; ".join(headers.get_all("Set-Cookie") or [])):
            LOG.info("%s rotated and persisted", "__Secure-1PSIDTS")

        # )]}'\n[["identity.hfcr",600],["di",N]] - the 600 is the next interval, in seconds.
        try:
            return int(json.loads(body[len(XSSI_PREFIX):])[0][1])
        except (IndexError, TypeError, ValueError, json.JSONDecodeError):
            return self._config["rotate_interval_s"]


def parse(payload):
    """The roster, out of an array with no keys in it."""
    if not isinstance(payload, list):
        raise UpstreamChanged("the RPC answered with something that is not an array")

    # payload[0] is the shared-people list, and a null there is the whole reason this check
    # exists rather than an `or []`.
    #
    # A dead session does not answer with a login page. It answers HTTP 200, WITH the )]}'
    # prefix, with valid JSON, and with null in this slot - observed, 126 bytes of consent
    # tokens. Read as "nobody is sharing" that becomes 200 {"people": []}, which is a valid
    # answer meaning something entirely different, and the panel draws an empty map with no
    # way to know. That is the exact confusion /v1/people refuses to allow, so it is refused
    # here where the two can still be told apart: a signed-in answer carries a LIST, empty or
    # not, and anything else is not a roster.
    if not payload or not isinstance(payload[0], list):
        raise SessionExpired(
            "the RPC answered without a roster in it (%d field(s), the first one %s) - that is "
            "what a session Google no longer recognises looks like, and it is NOT an empty "
            "roster; sign in again on the VNC screen"
            % (len(payload), type(payload[0]).__name__ if payload else "absent"))

    shared = payload[0]

    people = []
    without_fix = 0
    for index, entry in enumerate(shared):
        person = _person(entry, index)
        if person is None:
            without_fix += 1
            continue
        people.append(person)

    return people, without_fix


def _person(entry, index):
    try:
        identity = entry[6]
        location = entry[1]
    except (IndexError, TypeError):
        raise UpstreamChanged(f"people[{index}] has neither an identity nor a location block")

    # Somebody who shares but whose phone has not reported a position. A real entry with a
    # real name and no coordinate at all, and there is no honest way to draw them: lat and lon
    # are required on the panel's side, and one entry missing a required field throws away the
    # whole poll there. Counted, not invented.
    if not isinstance(location, list) or len(location) < 3 or not isinstance(location[1], list):
        return None

    try:
        person = {
            "id": str(identity[0]),
            "name": identity[2] or identity[3] or str(identity[0]),
            # [2] is the latitude and [1] the longitude, which is the other way round from
            # every signature that takes a pair.
            "lat": float(location[1][2]),
            "lon": float(location[1][1]),
            # Google counts in milliseconds here; the contract is epoch seconds, matching
            # everything in the panel's Sinks.hpp. A thousandfold error puts every fix in
            # 1970 and the panel believes it.
            "seen_at": int(location[2]) // 1000,
        }
    except (IndexError, TypeError, ValueError) as error:
        raise UpstreamChanged(f"people[{index}] is not the shape this reads ({error})")

    if len(location) > 3 and isinstance(location[3], (int, float)):
        person["accuracy_m"] = float(location[3])

    # Absent rather than null, and absent rather than a plausible number: the panel keeps a
    # battery nobody reported out of range on purpose, because 0% and "did not say" are
    # different facts about a phone.
    try:
        battery = entry[13][1]
    except (IndexError, TypeError):
        battery = None
    if isinstance(battery, (int, float)) and not isinstance(battery, bool):
        person["battery"] = int(battery)

    return person
