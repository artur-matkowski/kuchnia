"""The one published port: the roster, the tiles, the settings page and the VNC screen.

One port and one host name, path-routed, because the panel resolves one name and trusts one
certificate. Nothing here ever names that host: every link the page emits is relative and
noVNC builds its websocket URL from window.location, so the container never depends on the
DNS that fronts it in order to talk to itself.

Three paths are open because the panel's HTTP client has no credentials and follows no
redirects: /v1/people, /health and /tiles. Everything else is HTTP Basic behind the one
password in .env.
"""

import base64
import hmac
import html
import json
import logging
import os
import select
import socket
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .config import FIELDS

LOG = logging.getLogger("location.web")

WEB_USER = "admin"
REALM = "kuchnia location"

# websockify, which serves noVNC's own files as well as bridging the RFB socket. Loopback:
# nothing but this process may reach it.
VNC_WEB = ("127.0.0.1", 6080)

# How long a proxied connection may say nothing before it is dropped. An idle VNC screen is
# genuinely silent - the RFB server sends nothing until a pixel changes - so this is an hour
# and not a minute.
IDLE_TIMEOUT = 3600

PAGE = os.path.join(os.path.dirname(__file__), "ui.html")


def serve(port, password, config, roster, poller, tiles, signin):
    Handler.password = password
    Handler.config = config
    Handler.roster = roster
    Handler.poller = poller
    Handler.tiles = tiles
    Handler.signin = signin

    server = ThreadingHTTPServer(("", port), Handler)
    server.daemon_threads = True
    LOG.info("serving /v1/people, /tiles, /vnc and the settings page on :%d", port)
    server.serve_forever()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "kuchnia-location"
    sys_version = ""

    # Unbuffered, because /vnc hands this socket over to a byte pump and anything sitting in
    # a read buffer at that moment is lost without a word. The cost is that rfile.read(n) is
    # now a short read like any raw socket - see _read_exact, which every body goes through.
    rbufsize = 0

    password = None
    config = None
    roster = None
    poller = None
    tiles = None
    signin = None

    def do_GET(self):
        self._route()

    def do_POST(self):
        self._route()

    def _route(self):
        path = urllib.parse.urlparse(self.path).path

        # Matched exactly, and nothing here redirects: the panel's HTTP client treats any 3xx
        # as a failure, so a tidy trailing-slash redirect would read there as a dead service.
        if path == "/v1/people":
            self._json(*self.roster.serve())
            return
        if path == "/health":
            self._json(*self.roster.health())
            return

        if path.startswith("/tiles/"):
            tile = self.tiles.match(path)
            # Refused here rather than falling through to the password, because the panel
            # reads this prefix: a 401 would tell it the tile server wants credentials, and
            # send whoever debugged that looking at the proxy instead of at the URL.
            if tile is None:
                self._json(404, {"error": f"not a tile this serves: {path}"})
            else:
                self._tile(*tile)
            return

        if not self._authorised():
            self._unauthorised()
            return

        if path == "/vnc" or path.startswith("/vnc/"):
            self._proxy_vnc()
        elif path == "/" and self.command == "GET":
            self._page()
        elif path == "/settings" and self.command == "POST":
            self._settings()
        elif path == "/signin" and self.command == "POST":
            self._signin()
        else:
            self._json(404, {"error": f"no such path: {path}"})

    # -- the panel's three paths ---------------------------------------------------------

    def _tile(self, z, x, y):
        status, body, cached = self.tiles.get(z, x, y)
        if status != 200:
            self._json(status, {"error": f"no tile {z}/{x}/{y}"})
            return

        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(body)))
        # Ours and only ours. Upstream sends its own, much shorter, Cache-Control, and a
        # client handed both picks the wrong one - so the proxy answers rather than forwards.
        self.send_header("Cache-Control", "public, max-age=2592000, immutable")
        self.send_header("X-Tile-Cache", cached)
        self.end_headers()
        self.wfile.write(body)

    # -- the page ------------------------------------------------------------------------

    def _page(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        message = query.get("m", [""])[0]

        page = _read(PAGE)
        page = page.replace("{{MESSAGE}}", _message(message))
        page = page.replace("{{ROSTER}}", _roster(self.roster))
        page = page.replace("{{SIGNIN}}", _signin(self.signin))
        page = page.replace("{{SETTINGS}}", _settings(self.config.all()))

        body = page.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _settings(self):
        form = self._form()
        errors = self.config.update({name: values[0] for name, values in form.items()
                                     if name in FIELDS})
        if errors:
            self._back(" / ".join(errors))
            return
        # So that a changed interval is not first honoured at the end of the old one.
        self.poller.wake()
        self._back("Settings saved.")

    def _signin(self):
        action = self._form().get("action", [""])[0]
        if action == "start":
            self.signin.start()
        elif action == "finish":
            self.signin.finish()
        elif action == "cancel":
            self.signin.cancel()
        else:
            self._back(f"unknown sign-in action: {action!r}")
            return
        self._back(self.signin.message)

    def _back(self, message):
        # Relative on purpose: "./" resolves against whatever the browser actually asked for,
        # so the page works whether this is mounted at the root of a name or under a prefix.
        self.send_response(303)
        self.send_header("Location", "./?m=" + urllib.parse.quote(message))
        self.send_header("Content-Length", "0")
        self.end_headers()

    # -- the VNC screen -------------------------------------------------------------------

    def _proxy_vnc(self):
        """Everything under /vnc/ goes to websockify, static files and websocket alike.

        It serves noVNC's own files, so one proxy covers both - and a websocket is only a
        request whose answer is 101 and whose body never ends, which is why the hand-off below
        is the same code for both.
        """
        tail = self.path[len("/vnc"):] or "/"
        upgrade = self.headers.get("Upgrade", "").lower() == "websocket"

        try:
            upstream = socket.create_connection(VNC_WEB, timeout=10)
        except OSError as error:
            self._json(503, {"error": "the sign-in screen is not running - press Start on the "
                                      f"settings page ({error})"})
            return

        lines = [f"{self.command} {tail} HTTP/1.1"]
        for name, value in self.headers.items():
            lowered = name.lower()
            if lowered in ("host", "authorization"):
                continue
            if lowered == "connection" and not upgrade:
                continue
            lines.append(f"{name}: {value}")
        lines.append(f"Host: {VNC_WEB[0]}:{VNC_WEB[1]}")
        if not upgrade:
            # One upstream connection per asset. Without this the pump below would sit on a
            # keep-alive connection that has already said everything it is going to say.
            lines.append("Connection: close")

        try:
            upstream.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("latin-1"))
            length = int(self.headers.get("Content-Length") or 0)
            if length:
                upstream.sendall(self._read_exact(length))
        except OSError as error:
            upstream.close()
            self._json(502, {"error": f"the sign-in screen stopped answering ({error})"})
            return

        self.close_connection = True
        _pump(self.connection, upstream)

    # -- plumbing --------------------------------------------------------------------------

    def _authorised(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(header[6:], validate=True).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return False
        user, _, password = decoded.partition(":")
        # Both compared the constant-time way; a short-circuit on the user name leaks which
        # half was wrong.
        return (hmac.compare_digest(user, WEB_USER) &
                hmac.compare_digest(password, self.password))

    def _unauthorised(self):
        body = json.dumps({"error": "this path needs the password from services/.env"}).encode()
        self.send_response(401)
        self.send_header("WWW-Authenticate", f'Basic realm="{REALM}", charset="UTF-8"')
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _form(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self._read_exact(length).decode("utf-8", "replace")
        return urllib.parse.parse_qs(body, keep_blank_values=True)

    def _read_exact(self, length):
        """rfile is unbuffered - see rbufsize - so one read is one recv and may be short."""
        chunks = []
        remaining = length
        while remaining > 0:
            chunk = self.rfile.read(remaining)
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)

    def _json(self, status, body):
        payload = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        LOG.debug("%s - %s", self.address_string(), fmt % args)


def _pump(client, upstream):
    """Bytes both ways until either side goes quiet. Whatever they are speaking by then."""
    client.settimeout(None)
    upstream.settimeout(None)
    sockets = [client, upstream]
    try:
        while True:
            ready, _, _ = select.select(sockets, [], [], IDLE_TIMEOUT)
            if not ready:
                return
            for source in ready:
                data = source.recv(65536)
                if not data:
                    return
                (upstream if source is client else client).sendall(data)
    except OSError:
        return
    finally:
        # Only the upstream: the server owns the client socket and closes it after this.
        upstream.close()


def _read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


# -- the page's four blocks ------------------------------------------------------------------

def _message(text):
    if not text:
        return ""
    return f'<p class="message">{html.escape(text)}</p>'


def _roster(roster):
    people, age, without_fix, error = roster.snapshot()
    status, _ = roster.serve()

    rows = [_row("Status", "answering" if status == 200 else f"refusing with {status}")]
    rows.append(_row("Sharing", "-" if people is None else str(len(people))))
    if without_fix:
        rows.append(_row("Sharing but no fix", str(without_fix)))
    rows.append(_row("Last successful poll", "never" if age is None else f"{int(age)}s ago"))
    if error:
        rows.append(_row("Last error", error))

    names = ", ".join(person["name"] for person in people or []) or "nobody"
    rows.append(_row("On the map", names))
    return "\n".join(rows)


def _signin(signin):
    rows = [_row(name, state) for name, state in signin.state()]
    if signin.message:
        rows.append(_row("Last", signin.message))
    return "\n".join(rows)


def _settings(values):
    blocks = []
    for name, (_, kind, help_text) in FIELDS.items():
        value = html.escape(str(values[name]), quote=True)
        blocks.append(
            f'<label for="{name}">{html.escape(name)}</label>'
            f'<input id="{name}" name="{name}" value="{value}"'
            f'{" inputmode=numeric" if kind == "int" else ""}>'
            f'<p class="help">{html.escape(help_text)}</p>')
    return "\n".join(blocks)


def _row(label, value):
    return f"<tr><th>{html.escape(label)}</th><td>{html.escape(str(value))}</td></tr>"
