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

	// The type scale. Every size in the scene comes from here, because the panel is read from
	// two to three metres away and a literal pixel size written at a desk is always too small.
	readonly property int fontLabel:   16   // axis ends, captions, the status badge
	readonly property int fontBody:    22   // button labels, station names, gate state
	readonly property int fontReading: 44   // a number that is the point of its panel
	readonly property int fontHero:    64   // the two numbers read from across the room

	// The height of a row carrying one big reading instead of a chart. Both screens that show
	// the weather use it, and the migration between them depends on them agreeing: a card that
	// changes height on the way over reads as a card that was rebuilt rather than moved.
	readonly property int readingRow:  Math.round(fontHero * 1.7)
}
