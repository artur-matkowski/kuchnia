# Input

> Owns: src/app/KeyBindings.hpp
> Owns: src/app/KeyBindings.cpp
> Owns: src/qml/Actions.qml
> See:  docs/contexts.md docs/carousel.md docs/media.md docs/radio.md docs/volume.md docs/state.md docs/map.md docs/settings.md

A USB keyboard is the whole of the input; there is no pointer on the board. Every press
arrives at one handler in `src/qml/Main.qml`, becomes an action id through `KeyBindings`, and
is performed by `Actions`.

## One keycode, and nothing else

A binding is a keycode. Modifiers are no part of it, so Shift and a key run whatever the key
runs, and the keypad's Enter is a *different* keycode from the main one - `confirm` bound to
Return leaves the keypad's key doing nothing at all, which reads as a broken keyboard rather
than as two keys. Auto-repeat is dropped where the press arrives: held down, a gate key would
otherwise publish a command per repeat.

## The bindings file is not the config

`key-bindings` names an INI file of its own, and the parameter table in `Settings.cpp` is only
where its *path* comes from. That config is resolved once at startup out of a file, the
environment and argv; this one is written while the scene is running, by the settings screen.

An empty `key-bindings` is the standard per-user location, `~/.config/kuchnia/keys.ini`,
beside the config file the application writes for itself ([packaging](docs/packaging.md)).
`QSettings` reports a write it could not make only through `status()`, so without the check in
`save()` an unwritable home is a screen that takes a binding, draws it, and has forgotten it
by the next start.

**A missing entry takes its default; an entry that is present and empty is unbound on
purpose.** Escape writes the second. Conflate the two and every action somebody deliberately
cleared is bound again on the next start.

`--key-reset` erases the file and writes the defaults back, and it is the only way out of a
map that has bound the settings screen out of reach. `key-reset:true` left in a config *file*
instead of passed on argv resets on every boot, discarding every binding made since.

## Which action is performed where

`Actions.run` performs the actions whose state belongs to a singleton and announces them on
`invoked`. The radio's three are not among them: what is playing belongs to the `MediaPlayer`
in `RadioPanel.qml`, which answers them there.

`refresh` is two actions and **the context picks which, in `Actions.run` alone** — the compact
screen re-reads the radio playlists ([radio](docs/radio.md)), the map screen drops its tile
cache and re-polls the roster ([map](docs/map.md)), and on the other four contexts it does
nothing. Only the map's half is announced, because that tile cache belongs to the `Map` in
`MapPanel.qml`; the radio's is `Radio` singleton state, done in `run` itself, which then
**returns before announcing**.

It ships bound to **F5**, on the reasoning below that binds the camera keys: it commands no
hardware and undoes itself.

## The map's five are decided here and performed there

`map-people` opens and shuts the roster list, `map-previous`/`map-next` walk it, and
`map-zoom-in`/`map-zoom-out` move the zoom. `Actions.run` performs none of them: all of that
state belongs to the `Map` in `MapPanel.qml`, so `run` only **returns before announcing** off
the map context, exactly as `refresh` does. That gate is what lets `MapPanel`'s one handler
switch on the id and test nothing else — these six are announced on the map context and nowhere
else, and a seventh id announced there would silently reach it too.

They ship **bound**, on the same reasoning as the camera keys: none commands hardware and each
undoes itself. The defaults are F2 for the list, Up and Down for the walk, and PageUp/PageDown
for the zoom.

**Not Plus and Minus, which is what a reader reaches for.** The main row's unshifted key arrives
as `Key_Equal` and only its shifted form as `Key_Plus`, so a `Key_Plus` binding answers the
keypad and Shift rather than the key with `+` printed on it.

Up and Down are free everywhere but the settings screen, which answers them itself before the
action lookup — [settings](docs/settings.md). Harmless here, because none of the five does
anything off the map, but an action bound to either is an action that cannot fire there.

**A panel hears `invoked` only because every context is instantiated at startup and stays
instantiated** - see [contexts](docs/contexts.md). A panel built when its screen is opened would
hear nothing, and a key bound to it would do nothing off that screen and say nothing about it.

An id is written in `KeyBindings`' table, in `Actions.run`'s switch, and in the QML that draws
its row. `run` warns about an id it does not know and `BindingRow` warns about one the table
does not have; a table entry that no `case` handles is the silent one - its key is simply a
key that does nothing.

The table's **order** is load-bearing too: it is the order the settings screen walks its rows,
and the two are not compared — [settings](docs/settings.md).

The `label` beside it is what the settings screen prints, and it is Polish where the id is
not: `labels()` decodes the label with `fromUtf8` and the id with `fromLatin1`. Latin-1 on a
Polish label is a decode and not an error, so it is a screen of mojibake and no warning.

## The camera keys navigate; the one that goes back does not

`camera-1` to `camera-5` fill the CCTV screen with one camera and `camera-grid` drops back to
all five. The key of the camera already filling the screen also drops back, so one key does
both and nothing has to remember which. Pressed on another context the five go to the CCTV
screen first, as the gate keys work from every screen - and the way back goes with them, so
dropping the zoom returns to the context the key was pressed on, unless a context key has
already carried somebody off that screen. `Actions.run` names the camera and nothing else; both
the zoom and that journey are `Cctv`'s, and what they do to the screen is
[contexts](docs/contexts.md).

These six ship **bound**, to 1-5 and 0, where the radio's and the gate's ship unbound: a digit
that fills the screen with a camera commands no hardware and undoes itself. A bindings file
written before they existed has no entry for them, which is "never touched" and takes the
default - the rule above is what makes that work.

## Keys that cannot be bound, and keys that never arrive

A key with no entry in the active keymap arrives as `Qt::Key_unknown` - **the same value for
every such key**, and one with no text to write to the file. Bound, it would answer to every
unnamed button at once and read back as unbound on the next start. Remotes reach this easily:
a HID consumer-control node emits far more usages than any keymap names.

A media remote is also the case where a key that *is* named still never arrives. On a desktop
host the session grabs the transport keys for itself - KDE's `[mediacontrol]` block in
`kglobalshortcutsrc` takes Play, Pause, Stop, Next and Previous by default, GNOME the same set
- and a grabbed key goes to the grabber, never to the focused window. The screen simply waits,
which reads exactly like a binding that will not take. Nothing in the application can change
that; the grab is the session's. It is a host-only fault, because the board runs no session at
all. Confirm it before suspecting the code: if the key reaches the kernel but not the window,
it was grabbed.
