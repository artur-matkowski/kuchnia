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

	// CloudCoverCard's cloud-altitude bands, low to high, told apart by lightness - docs/scene.md.
	readonly property color cloudLow:   "#3d8bff"
	readonly property color cloudMid:   "#e0e0e0"
	readonly property color cloudHigh:  "#6e6e78"

	// CloudLayersCard's cloud bases, one per coverage threshold in Rest.cpp and in its order -
	// see docs/rest.md. Dim to bright, the reverse of ICM's, because the ground here is dark.
	readonly property var   cloudBase:  ["#4d5263", "#6f7689", "#949bad", "#bfc5d3", "#f2f4f8"]
	readonly property color cloudTop:   "#e0524b"
	readonly property color visibility: "#ffa133"

	// PrecipitationCard's series, told apart by lightness as well as hue - docs/scene.md.
	readonly property color rain:       cool
	readonly property color snow:       "#ffffff"
	readonly property color humidity:   "#44ee44"

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

	// A chart's value-axis gutter: fontBody times a character count - docs/charts.md.
	readonly property real chartGutter: fontBody * 3.2

	// The height of a row carrying one big reading instead of a chart: a Card's heading, its
	// margins and one fontHero line at a 1.2 line height. Not a multiple of fontHero alone - the
	// heading does not scale with the reading. See docs/scene.md.
	readonly property int readingRow:
		Math.round(fontLabel * 1.2 + fontHero * 1.2 + gap * 3)

	// The closest two forecast marks may stand, and the hour steps they thin to. Each step
	// divides the next, so thinning only ever takes marks away - see docs/charts.md.
	readonly property int sampleGap: 20

	function sampleStride(hourPx) {
		for (const hours of [1, 3, 6, 12, 24])
			if (hours * hourPx >= sampleGap)
				return hours
		return 24
	}
}
