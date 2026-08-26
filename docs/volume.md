# The volume keys

> Owns: src/app/Volume.hpp
> Owns: src/app/Volume.cpp
> See:  docs/input.md docs/media.md docs/session.md docs/packaging.md

Two keys, one step each, on the sound server's default sink. **Nothing here holds a level** —
no property to bind, no slider, no readout on any screen. `Volume::step()` runs
`pactl set-sink-volume @DEFAULT_SINK@ ±5%` as a child process and reads nothing back.

**A press that fails is invisible**, because the panel draws nothing a failure could
contradict. The two `LOG_ERROR` lines in `Volume.cpp` are the only report there will be. The
commonest is `pactl` not being installed, which arrives as `errorOccurred` and no `finished`;
`pulseaudio-utils` is a `Depends:` that `dh_shlibdeps` cannot see, alongside `ffmpeg` and the
server itself — [packaging](docs/packaging.md).

**`pactl` finds the right daemon only through `PULSE_SERVER`.** The board's server is
system-wide and the unit sets that variable for exactly that reason —
[session](docs/session.md). Lost from the environment, `pactl` reaches the per-user daemon
instead: it succeeds, it logs nothing, and it moves a sink nobody is listening to while the
radio and the cameras carry on unchanged. `wpctl` is the same trap one step worse, reaching
PipeWire directly and never reading `PULSE_SERVER` at all.

**There is no ceiling.** `pactl` takes the sink past 100% into software gain and keeps going.
`Main.qml` drops auto-repeat, so a held key is one step; the twentieth press is nothing this
stops.

## The session may own these keys first

`volume-up` and `volume-down` ship bound to `Qt::Key_VolumeUp` and `Qt::Key_VolumeDown`, and
reach this application only if the compositor hands them over. A session that binds them
itself either swallows them — the keys do nothing here and the volume still moves — or acts
alongside this, and one press moves the volume twice. Both read as a fault in this repository
and neither is one: the session's own bindings are where it is settled, or bind these two to
keys the session does not want.
