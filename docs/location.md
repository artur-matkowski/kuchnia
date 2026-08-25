# The location service: one container behind the map

> Owns: services/README.md
> Owns: services/Dockerfile
> Owns: services/docker-compose.yml
> Owns: services/.env.example
> Owns: services/entrypoint.sh
> Owns: services/supervisord.conf
> Owns: services/firefox-user.js
> Owns: services/app/__init__.py
> Owns: services/app/__main__.py
> Owns: services/app/config.py
> Owns: services/app/google.py
> Owns: services/app/roster.py
> Owns: services/app/signin.py
> Owns: services/app/tiles.py
> Owns: services/app/web.py
> Owns: services/app/selftest.py
> Owns: services/app/ui.html
> See:  docs/map.md docs/rest.md

Everything the map context needs that the panel must not do itself: the Google scrape, the
tiles, and the browser the Google session is renewed in. One container, one published port,
every path under it — `/v1/people`, `/tiles/{z}/{x}/{y}.png`, `/health`, `/` and `/vnc/`.
[services/README.md](services/README.md) is the runbook; the JSON contract is in
[map](docs/map.md) and is not repeated here.

**Nothing here builds or ships.** `CMakeLists.txt` does not glob and `debian/kuchnia.install`
names three files, neither of which reaches `services/`.

## The credential

There is no OAuth scope for location sharing, so **no sign-in flow can produce this
credential** — the RPC needs `__Secure-1PSID`, a full web-session cookie, and only a real
browser session yields one. That is why a browser and a person are in the loop at all, and why
no amount of work will replace them.

`__Secure-1PSID` is full account access. **The account is a burner**, everyone shares their
location *to* it, and that is what contains the risk. Automated access to the endpoint is
against Google's terms of service.

## What is silent

**A dead session is HTTP 200 with valid JSON.** Not a login page, not a 401. Google answers
the RPC with the `)]}'` prefix, nine fields of consent tokens, and **`null` where the roster
goes**. Read as "nobody is sharing" — which is what an `or []` does — that becomes a perfectly
valid `200 {"people": []}` and the panel draws an empty map with no way to know. `parse()`
therefore refuses anything but a **list** in that slot, as `SessionExpired`. A signed-in
answer with nobody sharing carries an empty list; a `null` there has never been observed from
a live session, and if one ever is, this is the line that will need a better discriminator
than the body.

**An expired session must never leave as `{"people": []}`.** Same reason, one layer up: an
empty roster is a real answer and nothing on the panel can tell the two apart from the body,
so every failure is a status code and a named reason. `/health` fails with it deliberately, so
whatever fronts this pulls the backend rather than serving a stale roster.

**A missing cookie jar is a 503 and not an exit.** The one place this argues with the
repository's fail-loud rule, and the reason is structural: the sign-in that writes that file
runs *in this same container*, while the service is already up. Exiting would mean the only
way to renew the credential can never be reached.

**A wrong `authuser` answers with a valid, empty roster.** It selects which signed-in account
the request is made as. Another account is not an error — it is a perfectly good answer about
somebody else, and nobody shares with them.

**The array indices are the whole parser.** Google's answer has no keys: `entry[6]` is the
identity, `entry[1]` the location, and inside it **`location[1][2]` is the latitude and
`location[1][1]` the longitude** — the other way round from every signature that takes a pair.
Google counts in milliseconds and the contract is epoch seconds, converted once. A moved field
draws somebody standing somewhere they are not, and the map draws that without complaint, so
`python3 -m app.selftest` pins the shapes.

**The jar is written back after every request, including failed ones.** Google mints a new
`__Secure-1PSIDTS` on most authenticated calls and a rotation dropped on the floor is a session
that dies at the next restart. The same rule persists Google's *deletions*: the first poll
after a session dies clears `__Secure-1PSID` out of the file, so a jar inspected afterwards is
missing the cookie it was harvested with. That is the poll doing its job, not a bad harvest.

**The leading dot is load-bearing.** `.google.com` is what makes one jar serve both
`www.google.com`, which is read, and `accounts.google.com`, which rotates. In the Netscape
format the dot and the second column are one fact written twice, and Python's loader asserts
that they agree — disagreeing is a `LoadError` naming neither.

## The browser

Firefox rather than Chromium because **its cookie store is plain SQLite** — it encrypts saved
logins, not cookies — so the harvest is a query rather than a browser-automation protocol.
Chromium's copy of the same values is encrypted against a keyring no container has.

**Firefox writes cookies.sqlite lazily and checkpoints it on a clean shutdown**, which is why
the harvest stops the browser first and waits for it. Two prefs in `firefox-user.js` are
load-bearing for the same reason: `privacy.sanitize.sanitizeOnShutdown` and
`privacy.clearOnShutdown.cookies` both off, or the file is emptied at exactly the moment it is
about to be read. The rest of that file is only about not putting a dialog in the way.

**There is no window manager on that display**, so nothing would size the window: `-width` and
`-height` match Xvnc's geometry, or the browser is drawn small in a corner of a black screen.
The trade is that no window can be moved or resized, which is survivable because the Google
sign-in is entirely in-page.

**The profile persists on purpose.** A fresh one is a fresh device to Google and earns a new
verification challenge every time.

## The screen, and what guards it

`VNC_PASSWORD` is checked as HTTP Basic in `web.py`, **not by the RFB server**. Debian's
tigervnc packages ship no `vncpasswd` at all, and RFB's own VncAuth uses only the first eight
characters of a password — so the HTTP check is both the possible one and the stronger one.
What makes that safe is that Xvnc runs with `-localhost` and websockify binds loopback: the
only route in is `/vnc/`, which is behind the password. **A `network_mode: host` would undo
that**, which is why the compose file has none.

`/vnc/` proxies to websockify, which serves noVNC's own files as well as bridging RFB — so one
handler covers both, a websocket being only a request whose answer is `101` and whose body
never ends. The handler reads unbuffered (`rbufsize = 0`) because it hands the socket to a byte
pump, and anything left in a read buffer at that moment is lost without a word.

**Mount this at the root of its own name.** The page's own links are relative, but noVNC builds
its websocket URL from the root, so a path prefix breaks the screen and nothing else.

## The tiles

`Cache-Control` is **replaced, not added**: upstream sends its own much shorter value and a
client handed both picks that one. The identifying `User-Agent` is not politeness — the
OpenStreetMap tile policy rejects a client that does not identify itself, the panel's own
`User-Agent` is `kuchnia`, and this proxy is the only client the tile server ever sees.

`map-tile-url` and this service's `/tiles/` prefix are one fact in two repositories, and the
**trailing slash** belongs to the panel's side — see [map](docs/map.md) for what a missing one
does.

## State

`data/`, `profile/` and `cache/` are bind mounts beside the compose file, so throwing the
deployment away is `rm -rf` in this repository. `data/cookies.txt` **is** the Google
credential; it and `.env` are gitignored.
