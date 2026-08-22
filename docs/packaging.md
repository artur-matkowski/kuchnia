# The package, and the repository it is delivered through

> Owns: debian/changelog
> Owns: debian/control
> Owns: debian/copyright
> Owns: debian/qt-hmi.conf
> Owns: debian/qt-hmi.install
> Owns: debian/qt-hmi.postinst
> Owns: debian/qt-hmi.service
> Owns: debian/rules
> Owns: debian/source/format
> Owns: .gitea/workflows/deb.yaml
> Owns: scripts/build-deb.sh
> See:  docs/targets.md docs/app.md docs/integrations.md

The board runs Raspberry Pi OS Lite, and the application reaches it as a `.deb` from this
Gitea's own Debian registry. `apt` is the whole deployment system: an update is
`apt upgrade`, a rollback is `apt install qt-hmi=<older>`, and a new board is one
`sources.list` line. Nothing is flashed and no image is built.

Lite is load-bearing. The desktop images run a compositor, and a compositor holds the CRTC
that `eglfs` needs.

## Putting a board on the repository

```sh
curl -fsSL https://git.example.com/api/packages/<REDACTED>/debian/repository.key \
  | sudo tee /etc/apt/keyrings/gitea-<REDACTED>.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/gitea-<REDACTED>.asc] \
https://git.example.com/api/packages/<REDACTED>/debian trixie main" \
  | sudo tee /etc/apt/sources.list.d/qt-hmi.list
sudo apt update && sudo apt install qt-hmi
sudoedit /etc/qt-hmi.conf          # the two passwords are empty in the shipped file
sudo systemctl start qt-hmi
```

`main` in the last position of that line is the channel. A test board writes `testing`
there instead, or writes both and always takes the newer.

## What `dh_shlibdeps` cannot find

`debian/control` names nine runtime dependencies by hand. They are not a belt-and-braces
list: none of them is discoverable from the binary.

The QML imports are the reason. `--as-needed` drops any library the object files do not
reference, and the scene reaches Quick through the engine rather than through a symbol — so
`libQt6Quick` is not among the binary's `NEEDED` entries at all, and `qml6-module-qtquick`
is the only thing that installs it. The rest of the imports in `src/qml/` follow the same
path, which is why every one of them is listed.

`libqt6opengl6` is where Debian keeps the `eglfs` platform plugin and its KMS/GBM
integration, and it pulls `libgbm1`, `libegl1`, `libdrm2` and `libinput10` behind it. It is
the single package that carries the display path.

Most of those fail at startup: the engine reports the import, `main.cpp` turns a failed root
object into `exit(1)`, and `Restart=always` makes that a restart loop with the reason in the
journal. **`ca-certificates` is the one that does not.** Poco verifies its peer against
`/etc/ssl/certs`, so without it the process starts, the scene draws, and only the forecast
stays empty — [docs/rest.md](docs/rest.md).

## The service user has nowhere to write

`qt-hmi` is a system account with no home, and two things write `QSettings` files while the
application runs: the key bindings ([docs/input.md](docs/input.md)) and the radio station in
`src/qml/RadioPanel.qml`. With no writable config location both are accepted, drawn, and
gone on the next start. `StateDirectory=qt-hmi` and `XDG_CONFIG_HOME=/var/lib/qt-hmi` in the
unit are what give them somewhere; nothing else in the package refers to that directory.

The unit grants `video`, `render` and `input` through `SupplementaryGroups`, so `postinst`
only has to create the account.

## The config file

`/etc/qt-hmi.conf` is a dpkg conffile, which is what makes a hand-edited copy survive an
upgrade, and it is where the passwords go — `postinst` sets it `0640 root:qt-hmi`. Nothing
in the package or in git ever carries a credential.

Two properties of the parser matter when editing it:

* **An empty value is the same as no line at all.** The parser drops empty fields, so
  `mqtt-user:` does not clear the compiled-in default — it leaves it in place.
* **An unreadable file is replaced, not reported.** A missing `/etc/qt-hmi.conf` makes the
  application write a default one; as the `qt-hmi` user it cannot, and it then runs on the
  compiled-in defaults having said so only at warning level.

The path is compiled into `src/integrations/Settings.cpp` and repeated in
`debian/qt-hmi.install` and `debian/qt-hmi.postinst`. Nothing checks that the three agree.

## Versions and channels

Branch `main` publishes to component `main`, branch `testing` to component `testing`, and
every other branch builds without publishing. Promotion is a merge.

The version is `1.0.<run number>`, with `~testing` appended off `main`. The run number is
per repository and only climbs, so a testing build always outranks the last main build; the
tilde sorts below everything, so the `1.0.7` that eventually promotes `1.0.7~testing`
outranks it in turn. It has nothing to do with the `VERSION` in `CMakeLists.txt`.

Old versions stay in the pool, which is what makes `apt install qt-hmi=1.0.6` a rollback.

`trixie` is written in `.gitea/workflows/deb.yaml`'s upload URL, in `scripts/build-deb.sh`,
and in every board's `sources.list`. All three are the same distribution and none of them
reads the others.

## Building it

`scripts/build-deb.sh` runs the same build CI runs — `--here` inside a `debian:trixie`
container, plain in a throwaway one. The build dependencies are never written twice:
`apt-get build-dep` reads them out of `debian/control`. The cross build itself, and the
`QT_HOST_PATH` pair `debian/rules` passes, are in [docs/targets.md](docs/targets.md).

Publishing needs a `PACKAGE_TOKEN` secret holding a Gitea token with `write:package`. Gitea
authenticates the token and ignores the username beside it, so the workflow sends a
placeholder. Nothing else in the run is authenticated — the checkout clones anonymously and
a board's `apt` reads the registry anonymously, both of which stop working the moment this
repository or the `<REDACTED>` organisation stops being public.
