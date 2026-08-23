# Input

> Owns: src/app/KeyBindings.hpp
> Owns: src/app/KeyBindings.cpp
> Owns: src/qml/Actions.qml
> Owns: src/qml/SettingsScreen.qml
> See:  docs/contexts.md docs/carousel.md docs/media.md docs/radio.md docs/state.md

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

An empty `key-bindings` is the standard per-user location, which is what the board uses - its
`/etc` is not writable. `QSettings` reports a write it could not make only through `status()`,
so without the check in `save()` an unwritable home is a screen that takes a binding, draws
it, and has forgotten it by the next start.

**A missing entry takes its default; an entry that is present and empty is unbound on
purpose.** Escape writes the second. Conflate the two and every action somebody deliberately
cleared is bound again on the next start.

`--key-reset` erases the file and writes the defaults back, and it is the only way out of a
map that has bound the settings screen out of reach. `key-reset:true` left in a config *file*
instead of passed on argv resets on every boot, discarding every binding made since.

## Which action is performed where

`Actions.run` performs the actions whose state belongs to a singleton, and announces every one
of them on `invoked`. The radio's three are not among them: what is playing belongs to the
`MediaPlayer` in `RadioPanel.qml`, and that panel answers them there.

**A panel hears `invoked` only because every context is instantiated at startup and stays
instantiated** - see [contexts](docs/contexts.md). A panel built when its screen is opened
would hear nothing, and a key bound to it would do nothing off that screen and say nothing
about it.

An id is written in `KeyBindings`' table, in `Actions.run`'s switch, and in the QML that draws
its row. `run` warns about an id it does not know and `BindingRow` warns about one the table
does not have; a table entry that no `case` handles is the silent one - its key is simply a
key that does nothing.

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

## The settings screen

The rows are drawn in the order the table lists them and nothing checks that they agree. Drawn
in another order, the selection appears to jump about the screen as it moves. The four cards
stand in two columns and the walk is **column-major** - down the left one, then down the right
- so the table's order is that walk and not a left-to-right reading of the screen.

Up and down walk the rows, and they are the only hardwired keys left in the application. That
is deliberate: they are not actions because a screen whose rows cannot be reached is a screen
that cannot be repaired.

An armed row takes every key press until it ends, which is what stops a binding being made out
of a key that did something on the way in. Three things end it:

* **Escape** unbinds the row and saves it that way. It is therefore the one key no action can
  hold.
* **Whatever `confirm` holds** cancels, leaving the row as it was.
* **Anything else** binds - unless the key is refused, and then the row says why and stays
  armed, so the next key can simply be tried. Two things are refused: a key another action
  already holds, and a key the platform has no name for.

Every other action stays live on this screen: a key bound to the gate opens the gate from
here too. Only an armed row swallows it.

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
