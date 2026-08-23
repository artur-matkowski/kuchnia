# The session the application is drawn into

> Owns: debian/qt-hmi.user.service
> Owns: debian/qt-hmi.desktop
> Owns: debian/qt-hmi-autostart
> See:  docs/packaging.md docs/scene.md docs/media.md docs/integrations.md

The application is an ordinary client of whatever compositor the board logs into. It picks no
platform and owns no connector: `QT_QPA_PLATFORM` is deliberately absent from the unit, so
one unit serves the labwc session and the X one beside it.

Three things have to be true before a frame appears, and each fails without saying so.

**The board has to log in at all.** On `multi-user.target` nothing below ever runs: the
package installs, the unit enables, and the screen stays dark with nothing in any log to say
why. `raspi-config nonint do_boot_behaviour B4` is what puts it back.

**`graphical-session.target` is never reached.** `/usr/bin/labwc-pi` execs the compositor and
starts no systemd target, leaving the user manager on `basic`, `default`, `paths`, `sockets`
and `timers`. The `WantedBy=` in the unit is correct where that target exists and inert here,
so what actually starts the unit is `debian/qt-hmi.desktop` in `/etc/xdg/autostart`.

**The user manager has no `WAYLAND_DISPLAY`.** It was started before the compositor, and a
unit started without that variable has no session to draw into. `debian/qt-hmi-autostart`
exists only to push it in before starting the unit. Raspberry Pi OS ships
`env-display.desktop` doing the same import, but XDG autostart entries have no defined order
between them, so relying on it is a race.

Which account the display manager autologs in decides who this runs as, and that account has
to be in the `qt-hmi` group to read the config — [packaging](docs/packaging.md). It is also
what gives `QSettings` a home: the key bindings ([docs/input.md](docs/input.md)) and the
radio station in `src/qml/RadioPanel.qml` land in that user's `~/.config`.

Fullscreen is the application's own request and not compositor configuration — the window is
[scene](docs/scene.md), the parameter behind it [integrations](docs/integrations.md).

## The two things the unit does set

`QT_FFMPEG_DECODING_HW_DEVICE_TYPES` is **empty**, and empty is the value: it leaves the
ffmpeg backend no hardware device type to choose, so the camera tiles decode in software.
Unset, the backend picks `h264_v4l2m2m` and the tiles stall — [media](docs/media.md).
`GST_PLUGIN_FEATURE_RANK` is the same intent aimed at the wrong backend and does nothing
here, which is worse than doing nothing elsewhere: it looks exactly like the fix.

`PULSE_SERVER` names the sound server because this board's is system-wide and shared with
`audio-host`, not the per-user one Qt looks for. The address is written in three places that do
not read each other: this unit, `/etc/pipewire/pipewire-pulse.conf.d/`, and `audio-host`'s
drop-in. Unreachable, it is silent and not broken — [media](docs/media.md).
