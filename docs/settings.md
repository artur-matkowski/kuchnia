# The settings screen

> Owns: src/qml/SettingsScreen.qml
> See:  docs/input.md docs/contexts.md docs/carousel.md docs/scene.md docs/map.md

One row per action: what it is, and the key that runs it. Which key that is, and what the
action then does, is [input](docs/input.md); this is only the screen.

It is off the left/right ring on purpose — `settings` is not in `Nav.cycle` — so the carousel
is the only way in and the menu key is the only way out.

## The table's order is the walk, and nothing checks it

The rows are drawn in the order `KeyBindings` lists its actions. Drawn in any other, the
selection appears to jump about the screen as it moves, because the two orders are the same
fact written in two files with nothing comparing them.

The walk is **column-major** — down the left column's cards, then down the right one's — and
the two columns do not hold the same number of cards. `KeyBindings`' table is therefore
Nawigacja, Mapa and Brama, then Dźwięk and Kamery.

## Why two row specs

`Cells.box` takes a column spec and a row spec, and nothing says both columns must use the same
row spec. `cell()` picks `leftRows` or `rightRows` by column, and that is the whole of what puts
three cards down one side and two down the other.

Equal thirds down the left would leave every card there **four** binding rows tall, one short of
the two that need five. So the gate's card — the only one with three rows — takes a height cut
to its own contents through `bindingCard()`, and the two flexible bands share what is left.

`bindingCard()` is written out of the parts, the way `Theme.readingRow` is, because the heading
does not scale with the rows. It carries one gap of headroom on purpose: `Card.contentTop`
measures its heading at runtime and this is only the type scale's figure for it, and **nothing
in this scene clips** — a card cut a pixel short is its last row drawn over the card beneath it.

Adding a row to a card is therefore not free. Five is what the left column's two flexible cards
hold and seven is what the right column's hold; past that the rows run out of the frame with no
warning anywhere.

## Up and down are the only hardwired keys left

They are not actions and cannot be bound. That is deliberate: a vertical list wants vertical
keys, and a screen whose rows cannot be reached is a screen that cannot be repaired. `Main.qml`
answers them **before** the action lookup and only on this context, so an action bound to Up or
Down — the map's two walk keys ship that way — simply does not fire here.

## An armed row takes every key there is

Or a binding could only ever be made out of keys that already do nothing. Three things end it:

* **Escape** unbinds the row and saves it that way. It is therefore the one key no action can
  hold.
* **Whatever `confirm` holds** cancels, leaving the row as it was.
* **Anything else** binds — unless the key is refused, and then the row says why and stays
  armed, so the next key can simply be tried. Two things are refused: a key another action
  already holds, and a key the platform has no name for ([input](docs/input.md) is why the
  second one cannot work).

Every other action stays live on this screen: a key bound to the gate opens the gate from here
too. Only an armed row swallows it.

## What each row draws

`BindingRow`'s `action` is written here and again in `KeyBindings`' own table. Misspelt, it is a
row with no label that answers to nothing — which looks like a binding that will not take, so it
warns on completion.

The key box is `Theme.fontBody * 11` wide and the label takes half the card, both of which are
what makes a third column impossible: a column narrow enough to fit three would be narrower than
the key box alone.
