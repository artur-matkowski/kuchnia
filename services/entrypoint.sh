#!/bin/sh
# Root runs this, and only this. Everything supervisord starts runs as kuchnia.
set -eu

if [ -z "${VNC_PASSWORD:-}" ]; then
	echo "VNC_PASSWORD is unset. It guards the VNC screen and the settings page, and there" >&2
	echo "is no default: copy services/.env.example to services/.env and set one." >&2
	exit 1
fi

# Bind mounts from services/ in the repository. Docker creates a missing one as root, and
# nothing that runs here is root.
mkdir -p /data /profile /cache
chown kuchnia:kuchnia /data /profile /cache

# Ours rather than the person's, so it is rewritten on every start: it turns off the three
# dialogs that would otherwise be between them and the sign-in form, and it pins the two
# prefs that would throw the cookies away at shutdown - which is exactly when they are read.
cp /app/firefox-user.js /profile/user.js
chown kuchnia:kuchnia /profile/user.js

exec supervisord -c /etc/supervisor/supervisord.conf
