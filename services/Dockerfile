# One container: the roster, the tile cache, the settings page, and the browser the Google
# session is renewed in. See docs/location.md in this repository.
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# firefox-esr rather than chromium: its cookie store is plain SQLite, so taking the session
# out of it is a query rather than a browser-automation protocol. Chromium encrypts the same
# values against a keyring no container has.
#
# tigervnc-standalone-server rather than Xvfb + x11vnc: Xvnc is both, in one process.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        firefox-esr \
        fonts-dejavu-core \
        novnc \
        python3 \
        supervisor \
        tigervnc-standalone-server \
        websockify \
    && rm -rf /var/lib/apt/lists/*

# Everything runs as this. The bind mounts are chowned to it by the entrypoint, which is the
# only thing here that needs to be root.
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin kuchnia

WORKDIR /app
COPY app/ /app/app/
COPY firefox-user.js /app/firefox-user.js
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# The roster, the tiles, the settings page and the VNC screen are all paths under this one.
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
