# The session the application is drawn into

> Owns: debian/kuchnia.user.service
> Owns: debian/kuchnia.desktop
> Owns: debian/kuchnia-autostart
> Owns: debian/kuchnia-session-keys
> Owns: debian/labwc-rc.xml
> See:  docs/packaging.md docs/scene.md docs/media.md docs/volume.md docs/integrations.md docs/input.md

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
so what actually starts the unit is `debian/kuchnia.desktop` in `/etc/xdg/autostart`.

**The user manager has no `WAYLAND_DISPLAY`.** It was started before the compositor, and a
unit started without that variable has no session to draw into. `debian/kuchnia-autostart`
exists only to push it in before starting the unit. Raspberry Pi OS ships
`env-display.desktop` doing the same import, but XDG autostart entries have no defined order
between them, so relying on it is a race.

Which account the display manager autologs in decides who this runs as, and that account's
`~/.config` is where everything the application keeps lands: its own config file
([packaging](docs/packaging.md)) and the key bindings ([docs/input.md](docs/input.md)). A home
it cannot write is a start that refuses.

Fullscreen is the application's own request and not compositor configuration — the window is
[scene](docs/scene.md), the parameter behind it [integrations](docs/integrations.md).

## The keys the compositor eats

`/etc/xdg/labwc/rc.xml` binds `XF86AudioRaiseVolume`, `XF86AudioLowerVolume` and
`XF86AudioMute` to `wfpanelctl volumepulse`, and a matched labwc keybind is **consumed** — so
those three reach no client, and a key bound to them in the settings screen is dead with
nothing anywhere to say why ([input](docs/input.md)). `debian/labwc-rc.xml` takes them back,
as three empty `<keybind>` elements, which is labwc's idiom for unbinding.

**It augments the system file only because `labwc-pi` execs `labwc -m`.** Without
`--merge-config` labwc reads the *first* rc.xml it finds and nothing else, and this file would
then be the whole configuration — every other keybind on the board gone, silently.

**No XML comment may be added to it.** labwc has been reported to ignore an rc.xml that carries
one, and the file it is merged over holds none either. The failure is the whole file going
unread, which looks like the keys were never unbound.

`debian/kuchnia-session-keys` places it, from `ExecStartPre` of the unit: there it is already
the session account, `$HOME` is right without parsing lightdm's autologin setting, and the
compositor is up to be reloaded. It writes only when the file is absent, and never over one it
did not write. **`/etc/xdg/labwc/rc.xml` is a conffile of `rpd-wayland-core` and must not be
edited** — a package that edits it takes a dpkg prompt on every upgrade of that package, and
loses the edit to whoever answers it.

## The one thing the unit does set

Nothing here steers a video decoder any more. The camera tiles decode in an ffmpeg child
process which is asked for no hardware acceleration, so a `QT_FFMPEG_*` or
`GST_PLUGIN_FEATURE_RANK` line added here would reach only the radio, which decodes no video
at all — a variable that looks exactly like the fix and does nothing.

`PULSE_SERVER` names the sound server because this board's is system-wide and shared with
`audio-host`, not the per-user one Qt looks for. The address is written in three places that do
not read each other: this unit, `/etc/pipewire/pipewire-pulse.conf.d/`, and `audio-host`'s
drop-in. Unreachable, it is silent and not broken — [media](docs/media.md).
