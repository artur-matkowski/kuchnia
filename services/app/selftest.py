"""python3 -m app.selftest - the parts that fail quietly, exercised without Google.

The roster parser is a list of fixed indices into an undocumented array. Every other kind of
mistake here announces itself; this one draws somebody standing somewhere they are not, and
the map is perfectly happy to draw it. So the shapes are pinned here rather than trusted.

Nothing in this file talks to the network or needs a credential.
"""

import http.cookiejar
import json
import os
import sys
import tempfile
import time

from . import google
from .config import validate
from .roster import Roster
from .signin import SignIn, _is_google
from .tiles import Tiles

WARSAW = (<COORD_REDACTED>, <COORD_REDACTED>)


class Stub(dict):
    """Enough of Config to run Roster and Tiles."""


def entry(id_="1", display="Ala", fallback="ala@example.com",
          lat=WARSAW[0], lon=WARSAW[1], ms=1756100000123, accuracy=25.0, battery=73,
          located=True):
    """One sharing person, in Google's own shape: a list with meaning only at fixed indices."""
    row = [None] * 14
    row[1] = [None, [None, lon, lat], ms, accuracy] if located else [None, None, None]
    row[6] = [id_, None, display, fallback]
    row[13] = [None, battery] if battery is not None else None
    return row


def check(name, condition, detail=""):
    print(f"{'PASS' if condition else 'FAIL'}  {name}{'  ' + detail if detail else ''}")
    return bool(condition)


def raises(name, exception, call):
    try:
        call()
    except exception as error:
        return check(name, True, f"({error})")
    except Exception as error:  # noqa: BLE001
        return check(name, False, f"raised {type(error).__name__} instead: {error}")
    return check(name, False, "raised nothing")


def parser():
    ok = []
    people, without_fix = google.parse([[entry()]])
    person = people[0]

    ok.append(check("one sharing person parses", len(people) == 1 and without_fix == 0))
    ok.append(check("latitude comes from location[1][2]", person["lat"] == WARSAW[0],
                    f"got {person['lat']}"))
    ok.append(check("longitude comes from location[1][1]", person["lon"] == WARSAW[1],
                    f"got {person['lon']}"))
    ok.append(check("milliseconds become epoch seconds", person["seen_at"] == 1756100000,
                    f"got {person['seen_at']}"))
    ok.append(check("accuracy is carried", person["accuracy_m"] == 25.0))
    ok.append(check("battery is carried", person["battery"] == 73))
    ok.append(check("name is identity[2]", person["name"] == "Ala"))
    ok.append(check("id is a string", person["id"] == "1"))

    people, _ = google.parse([[entry(battery=None)]])
    ok.append(check("an unreported battery is ABSENT, not zero",
                    "battery" not in people[0], f"got {people[0].get('battery')!r}"))

    people, _ = google.parse([[entry(display=None)]])
    ok.append(check("name falls back to identity[3]", people[0]["name"] == "ala@example.com"))

    people, _ = google.parse([[entry(display=None, fallback=None, id_="42")]])
    ok.append(check("name falls back to the id", people[0]["name"] == "42"))

    people, without_fix = google.parse([[entry(), entry(id_="2", located=False)]])
    ok.append(check("a sharer with no fix is skipped and counted",
                    len(people) == 1 and without_fix == 1))

    people, without_fix = google.parse([[]])
    ok.append(check("an EMPTY LIST of sharers is an empty roster, not an error",
                    people == [] and without_fix == 0))

    # The one Google actually sends when the cookie jar is no longer a session: 200, with the
    # XSSI prefix, valid JSON, and null where the roster goes. Read as "nobody is sharing" it
    # is a 200 with an empty list, and the panel cannot tell that from the truth.
    dead = [None, None, "0ahUKEwjJqJrys7yWAxVTV0cBHcpMOGIQ8ZABCAE",
            "Xd6NaomGINOunboPypnhkQY", None, None, "GgA=", 1800, 1787682397524]
    ok.append(raises("a NULL roster is a dead session, never an empty one",
                     google.SessionExpired, lambda: google.parse(dead)))

    ok.append(raises("a payload that is not an array is named",
                     google.UpstreamChanged, lambda: google.parse({"people": []})))

    broken = entry()
    broken[1] = [None, [None, "east", "north"], 1756100000123]
    ok.append(raises("a coordinate that is not a number names the person index",
                     google.UpstreamChanged, lambda: google.parse([[broken]])))

    headless = entry()
    headless[6] = None
    ok.append(raises("an entry with no identity block is named",
                     google.UpstreamChanged, lambda: google.parse([[headless]])))

    return ok


def policy():
    ok = []
    config = Stub(stale_after_s=300)
    roster = Roster(config)

    status, body = roster.serve()
    ok.append(check("before the first poll it refuses", status == 503 and "error" in body))

    roster.succeed([], 0)
    status, body = roster.serve()
    ok.append(check("nobody sharing is 200 with an empty list, NEVER 503",
                    status == 200 and body == {"people": []}, f"got {status} {body}"))

    roster.succeed([{"id": "1"}], 2)
    status, body = roster.serve()
    ok.append(check("without_fix is reported beside the people",
                    status == 200 and body["without_fix"] == 2))

    roster.fail("the session expired")
    status, body = roster.serve()
    ok.append(check("a failure behind a fresh poll still serves the poll", status == 200))

    roster._fetched_at = time.time() - 3600
    status, body = roster.serve()
    ok.append(check("a stale poll refuses and names the reason",
                    status == 503 and "the session expired" in body["error"],
                    body.get("error", "")))
    ok.append(check("/health agrees with /v1/people", roster.health()[0] == 503))

    return ok


def jar():
    """The harvest writes it, the session reads it. Two files, one format, nothing checks."""
    ok = []
    with tempfile.TemporaryDirectory() as scratch:
        path = os.path.join(scratch, "cookies.txt")
        signin = SignIn.__new__(SignIn)
        signin._cookies = path
        signin._write([
            (".google.com", "__Secure-1PSID", "session-value", "/", 0, 1),
            (".google.com", "__Secure-1PSIDTS", "rotating", "/", 4102444800, 1),
            ("accounts.google.com", "HOSTONLY", "x", "/", 4102444800, 0),
        ])

        loaded = http.cookiejar.MozillaCookieJar(path)
        loaded.load(ignore_discard=True, ignore_expires=True)
        names = {cookie.name for cookie in loaded}
        ok.append(check("a harvested jar loads back", names == {
            "__Secure-1PSID", "__Secure-1PSIDTS", "HOSTONLY"}, str(sorted(names))))

        dotted = [c for c in loaded if c.name == "__Secure-1PSID"][0]
        ok.append(check("the leading dot survives, so one jar serves www and accounts",
                        dotted.domain == ".google.com" and dotted.domain_specified))
        ok.append(check("a session cookie survives the round trip",
                        dotted.value == "session-value"))
        ok.append(check("the file is not world readable",
                        oct(os.stat(path).st_mode)[-3:] == "600",
                        oct(os.stat(path).st_mode)[-3:]))

    ok.append(check("google.com and its subdomains match", _is_google(".google.com")
                    and _is_google("accounts.google.com") and _is_google("google.com")))
    ok.append(check("a lookalike domain does not", not _is_google("notgoogle.com")
                    and not _is_google("google.com.evil.net")))
    return ok


def tiles():
    ok = []
    cache = Tiles(Stub(tile_ttl_days=30), "/nowhere")
    ok.append(check("a well-formed tile matches", cache.match("/tiles/8/137/83.png") == (8, 137, 83)))
    ok.append(check("zoom 20 is refused", cache.match("/tiles/20/1/1.png") is None))
    ok.append(check("outside the pyramid is refused", cache.match("/tiles/2/9/1.png") is None))
    ok.append(check("a non-tile path is refused", cache.match("/tiles/8/137/83.jpg") is None))
    return ok


def settings():
    ok = []
    kept, errors = validate({"poll_interval_s": "45"})
    ok.append(check("a number arrives as a number", kept == {"poll_interval_s": 45} and not errors))
    _, errors = validate({"poll_interval_s": "0"})
    ok.append(check("a zero interval is refused", bool(errors), str(errors)))
    kept, _ = validate({"tile_upstream": "https://tile.openstreetmap.org/"})
    ok.append(check("a trailing slash on the tile upstream is trimmed",
                    kept["tile_upstream"] == "https://tile.openstreetmap.org"))
    _, errors = validate({"nonsense": "1"})
    ok.append(check("an unknown setting is refused", bool(errors)))
    return ok


def main():
    results = []
    for name, run in (("the roster parser", parser),
                      ("what /v1/people answers", policy),
                      ("the cookie jar", jar),
                      ("the tile paths", tiles),
                      ("the settings", settings)):
        print(f"\n-- {name} " + "-" * (60 - len(name)))
        results += run()

    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
