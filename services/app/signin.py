"""Signing in as the burner, and taking the cookies back out of the browser.

This step cannot be scripted, and it is worth saying why plainly because the obvious thing to
ask for does not exist: there is no "sign in with Google" that produces this credential. OAuth
issues scoped tokens and there is no location-sharing scope; the RPC needs __Secure-1PSID, a
full web-session cookie, and only a real browser session yields one.

So the sign-in gets a screen and a person, and only the harvest is automated. The browser, its
X server and the websocket bridge are supervisor programs with autostart off - they exist for
the few minutes somebody is signing in, not for the months in between.
"""

import glob
import logging
import os
import shutil
import sqlite3
import tempfile
import xmlrpc.client

from supervisor.xmlrpc import SupervisorTransport

LOG = logging.getLogger("location.signin")

# In the order they have to come up: the display first, because the browser attaches to it.
PROGRAMS = ("xvnc", "websockify", "browser")

# supervisor's own fault codes for "you asked for a state it is already in".
ALREADY_STARTED = 60
NOT_RUNNING = 70


class HarvestError(Exception):
    """The browser is not signed in, or its cookies are not readable."""


class SignIn:
    def __init__(self, supervisor_url, profile_dir, cookies_file):
        # Over supervisord's unix socket rather than a loopback port, because a socket is
        # guarded by its file mode - 0700, owned by this user - where a port is reachable by
        # anything sharing the container's network namespace.
        self._supervisor = xmlrpc.client.ServerProxy(
            "http://localhost", transport=SupervisorTransport(None, None, supervisor_url))
        self._profile = profile_dir
        self._cookies = cookies_file
        self.message = ""

    # -- the screen -------------------------------------------------------------------

    def state(self):
        """[(program, statename)], for the page. An unreachable supervisor is not fatal."""
        rows = []
        for name in PROGRAMS:
            try:
                rows.append((name, self._supervisor.supervisor.getProcessInfo(name)["statename"]))
            except Exception as error:  # noqa: BLE001
                rows.append((name, f"unknown ({error})"))
        return rows

    def running(self):
        return any(state == "RUNNING" for _, state in self.state())

    def start(self):
        for name in PROGRAMS:
            self._start(name)
        self.message = ("The screen is up. Open it, sign in as the burner account, then come "
                        "back and press Finish.")

    def cancel(self):
        self._stop_all()
        self.message = "Screen closed. Nothing was harvested."

    def finish(self):
        """Stop the browser, take its cookies, and put the screen away.

        The browser is stopped FIRST and waited for. Firefox writes cookies.sqlite lazily and
        checkpoints it on a clean shutdown, so reading it out from under a running browser is
        reading a file that may not have the cookie in it yet.
        """
        self._stop("browser")

        try:
            count = self.harvest()
        except HarvestError as error:
            # Leave the screen up and the browser back on it: whatever went wrong, the person
            # is standing right there and the profile still holds whatever they did.
            self._start("browser")
            self.message = f"Nothing harvested: {error}"
            return False

        self._stop_all()
        self.message = (f"Harvested {count} cookie(s) into {self._cookies}. "
                        "The roster picks it up on its next poll.")
        return True

    # -- the cookies ------------------------------------------------------------------

    def harvest(self):
        """Firefox's cookie store to a Netscape jar. Answers how many cookies were written.

        Firefox keeps cookies in plain SQLite - it encrypts saved logins, not cookies - so
        this is a query rather than a browser-automation protocol.
        """
        with tempfile.TemporaryDirectory() as scratch:
            source = os.path.join(self._profile, "cookies.sqlite")
            if not os.path.exists(source):
                raise HarvestError(
                    f"there is no {source} - the browser has not been signed in yet")

            # The -wal and -shm beside it, or a copy of the database alone can be missing the
            # most recent writes entirely.
            for path in [source] + glob.glob(source + "-*"):
                shutil.copy2(path, scratch)

            copy = os.path.join(scratch, "cookies.sqlite")
            try:
                connection = sqlite3.connect(f"file:{copy}?mode=ro", uri=True)
                rows = connection.execute(
                    "SELECT host, name, value, path, expiry, isSecure FROM moz_cookies "
                    "WHERE originAttributes = ''").fetchall()
                connection.close()
            except sqlite3.Error as error:
                raise HarvestError(f"{source} is not readable ({error})")

        cookies = [row for row in rows if _is_google(row[0])]
        names = {row[1] for row in cookies}
        if "__Secure-1PSID" not in names:
            raise HarvestError(
                "the profile has no __Secure-1PSID cookie for google.com, so it is not a "
                f"signed-in session (it has: {', '.join(sorted(names)) or 'nothing'})")

        self._write(cookies)
        LOG.info("harvested %d google.com cookie(s) into %s", len(cookies), self._cookies)
        return len(cookies)

    def _write(self, cookies):
        lines = ["# Netscape HTTP Cookie File"]
        for host, name, value, path, expiry, secure in cookies:
            lines.append("\t".join([
                host,
                # This column and the leading dot are one fact written twice, and Python's
                # loader asserts that they agree - disagreeing is a LoadError naming neither.
                "TRUE" if host.startswith(".") else "FALSE",
                path or "/",
                "TRUE" if secure else "FALSE",
                str(int(expiry)) if expiry and int(expiry) > 0 else "0",
                name,
                value,
            ]))

        directory = os.path.dirname(self._cookies) or "."
        handle = tempfile.NamedTemporaryFile(
            "w", dir=directory, prefix=".cookies-", delete=False, encoding="utf-8")
        try:
            handle.write("\n".join(lines) + "\n")
            handle.close()
            os.chmod(handle.name, 0o600)
            # Atomic, and in the same directory: the session watches this file's mtime and
            # would otherwise load a jar that is half written.
            os.replace(handle.name, self._cookies)
        except OSError:
            os.unlink(handle.name)
            raise

    # -- supervisor -------------------------------------------------------------------

    def _start(self, name):
        try:
            self._supervisor.supervisor.startProcess(name, True)
        except xmlrpc.client.Fault as fault:
            if fault.faultCode != ALREADY_STARTED:
                raise

    def _stop(self, name):
        try:
            self._supervisor.supervisor.stopProcess(name, True)
        except xmlrpc.client.Fault as fault:
            if fault.faultCode != NOT_RUNNING:
                raise

    def _stop_all(self):
        for name in reversed(PROGRAMS):
            self._stop(name)


def _is_google(host):
    """google.com and everything under it, and nothing that merely ends in the same letters."""
    host = (host or "").lstrip(".").lower()
    return host == "google.com" or host.endswith(".google.com")
