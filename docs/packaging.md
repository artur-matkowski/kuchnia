# The package, and the repository it is delivered through

> Owns: debian/changelog
> Owns: debian/control
> Owns: debian/copyright
> Owns: debian/kuchnia.install
> Owns: debian/kuchnia.postinst
> Owns: debian/rules
> Owns: debian/source/format
> Owns: scripts/build-deb.sh
> See:  docs/ci.md docs/session.md docs/targets.md docs/app.md docs/integrations.md docs/volume.md
> See:  docs/versioning.md

The board runs Raspberry Pi OS Desktop, and the application reaches it as a `.deb` from this
Gitea's own Debian registry. `apt` is the whole deployment system: an update is
`apt upgrade`, a rollback is `apt install kuchnia=<older>`, and a new board is one
`sources.list` line. Nothing is flashed and no image is built.

The desktop session is load-bearing: the package ships no display configuration at all and
draws as an ordinary client of whatever compositor the board logs into.

## Putting a board on the repository

The host below is a placeholder — that registry is private; `scripts/build-deb.sh` builds one.

```sh
curl -fsSL https://git.example.com/api/packages/<org>/debian/repository.key \
  | sudo tee /etc/apt/keyrings/gitea-kuchnia.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/gitea-kuchnia.asc] \
https://git.example.com/api/packages/<org>/debian trixie main" \
  | sudo tee /etc/apt/sources.list.d/kuchnia.list
sudo apt update && sudo apt install kuchnia
sudo raspi-config nonint do_boot_behaviour B4    # boot into the session, not the console
# log in once, then, as that account:
$EDITOR ~/.config/kuchnia/config.conf            # addresses and the two passwords
```

`main` in the last position of that line is the channel. A test board writes `testing`
there instead, or writes both and always takes the newer.

The `raspi-config` line is the difference between an installed package and a running one —
[session](docs/session.md). The editor line comes after the first start because that start
is what writes the file.

## What `dh_shlibdeps` cannot find

`debian/control` names fifteen runtime dependencies by hand. They are not a belt-and-braces
list: none of them is discoverable from the binary. **Three of them are not libraries at all.**
`ffmpeg` is forked per camera tile, `snapclient` for a synced radio station
([radio](docs/radio.md)) and `pactl` for the volume: no linkage or QML import reveals any of
them, and a board missing one fails with "No such file or directory" ([media](docs/media.md)).

**Installing `snapclient` starts one.** Its package enables `snapclient.service`: a second
client as `_snapclient`, browsing mDNS, with no `PULSE_SERVER` and outside this application's
mute arbitration. `postinst` disables it, and `deb-systemd-helper` makes that stick.

The QML imports are the reason. `--as-needed` drops any library the object files do not
reference, and the scene reaches Quick through the engine rather than through a symbol — so
`libQt6Quick` is not among the binary's `NEEDED` entries at all, and `qml6-module-qtquick`
is the only thing that installs it. The rest of the imports in `src/qml/` follow the same
path, which is why every one of them is listed.

`qt6-wayland` is the platform plugin the session needs, and it is the one dependency whose
absence degrades instead of failing: with a compositor running and no Wayland plugin, Qt
falls back to `xcb` over XWayland and draws a working but needlessly indirect picture.

Most of those fail at startup: the engine reports the import, `main.cpp` turns a failed root
object into `exit(1)`, and `Restart=always` makes that a restart loop with the reason in the
journal. **Two do not.** `ca-certificates`: Poco verifies its peer against `/etc/ssl/certs`,
so without it the process starts, the scene draws, and only the forecast stays empty —
[docs/rest.md](docs/rest.md). The PulseAudio server is the other, below.

`pipewire-pulse | pulseaudio` in `Depends`, and an address in the unit — the server itself is
board configuration, and on this board it is system-wide and shared. Why a server is needed
at all, and why the address has to be said out loud, is [media](docs/media.md).
`pulseaudio-utils` is beside it and is the second program the application forks: without it
the volume keys are silent no-ops with a line in the log — [volume](docs/volume.md).

How the unit, the autostart entry and the session fit together is
[session](docs/session.md). Nothing in this node configures a display.

## The version the settings screen prints

`debian/changelog` is where the version lives, and `debian/rules` hands it to CMake as
`KUCHNIA_VERSION`. So the string on that screen is the version `apt` installed and nothing
else; CI rewrites the changelog on every build with the number that build's history folds to
([versioning](docs/versioning.md)).

Outside the package `KUCHNIA_VERSION` is unset and CMake asks `versioner` the same question; a
tree with neither the submodule nor git reports `unknown`. **It is resolved when CMake
configures**, so a desktop build keeps whatever string it was configured with: rebuilding
after a commit still prints the old one until CMake runs again.

## The config file the package does not ship

**The package carries no configuration.** `~/.config/kuchnia/config.conf` belongs to the
account that logs in, and the application writes it on a start that finds none: every
parameter in `specs()` at its compiled-in default, `0600` because both passwords go there. A
fresh install draws a scene with no camera, database or broker in it until that account edits
the file. The path is resolved in `src/integrations/Settings.cpp` and nowhere else.

**Two files land in that directory and no more**: `config.conf`, and `keys.ini` beside it for
the key bindings ([input](docs/input.md)), which `QSettings` names from the two strings
`KeyBindings::open()` passes it. Nothing sets an application-wide organisation or application
name, so nothing else here has a `QSettings` path at all — a third file appearing under
`~/.config/kuchnia` is something new writing one.

**`/etc/kuchnia.conf` is not read, and not removed.** dpkg keeps a conffile that a new version
stops shipping and no `rm_conffile` is declared, so an upgraded board still holds the only
copy of its passwords; `postinst` says so when it finds one, because which account to copy
them to is not knowable from a maintainer script.

## Versions and channels

Branch `main` publishes to component `main`, branch `testing` to component `testing`, and
every other branch builds without publishing. Promotion is a merge — how a version is
numbered is [versioning](docs/versioning.md), what the run costs is [ci](docs/ci.md).

Old versions stay in the pool, which is what makes `apt install kuchnia=1.1.0` a rollback.

`trixie` is written in `.gitea/workflows/deb.yaml`'s upload URL, in `scripts/build-deb.sh`,
and in every board's `sources.list`. All three are the same distribution and none of them
reads the others.

## Building it

`scripts/build-deb.sh` runs the same build CI runs, in the same image — [ci](docs/ci.md).
The build dependencies are never written twice: `apt-get build-dep` reads them out of
`debian/control`. The cross build itself, and the `QT_HOST_PATH` pair `debian/rules` passes,
are in [docs/targets.md](docs/targets.md).
