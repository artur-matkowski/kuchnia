pragma Singleton
import QtQuick

// One place for the palette, so a scene that is still unstyled does not have to be
// re-coloured file by file when it stops being.
QtObject {
	readonly property color background: "#101014"
	readonly property color surface:    "#191922"
	readonly property color border:     "#2b2b38"
	readonly property color text:       "#e6e6f0"
	readonly property color textDim:    "#8b8b9e"

	readonly property color accent:     "#4aa3ff"
	readonly property color hot:        "#ff7a45"
	readonly property color cool:       "#4ad0ff"

	// The selected row of a list, and not the pressed state of a button. Accent at full
	// strength behind a whole row is a slab from three metres away; this is the same colour at
	// a fifth of it, so the row is marked rather than inverted.
	readonly property color highlight:  "#334aa3ff"

	// The rules inside a chart. Lighter than `border`, which is an edge drawn against the
	// background and is nearly invisible against `surface` - a grid that cannot be seen from
	// the sofa is a grid that was not drawn. Still far under the line it sits behind.
	readonly property color grid:       "#33333f"

	// The daylight wash behind a forecast chart. Low alpha on purpose: night is the bare
	// surface and day is lit, so the bands never compete with the line drawn over them.
	readonly property color daylight:   "#16ffc76b"

	readonly property color live:       "#3ecf6b"
	readonly property color connecting: "#e0b341"
	readonly property color failed:     "#ff4f5e"

	readonly property int gap: 8

	// The type scale, in pixels of the board's 1920x1080 panel, which is read from two to three
	// metres away. Every size in the scene comes from here; a literal size written at a desk is
	// always too small and nothing says so.
	readonly property int fontLabel:   22   // captions, a card's title, the status badge
	readonly property int fontBody:    30   // button labels, station names, a chart's axis
	readonly property int fontReading: 62   // a number that is the point of its panel
	readonly property int fontHero:    90   // the two numbers read from across the room

	// The height of a row carrying one big reading instead of a chart: a Card's heading, its
	// margins and one fontHero line at a 1.2 line height. Not a multiple of fontHero alone - the
	// heading does not scale with the reading. See docs/scene.md.
	readonly property int readingRow:
		Math.round(fontLabel * 1.2 + fontHero * 1.2 + gap * 3)
}
