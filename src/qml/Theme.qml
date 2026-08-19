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

	readonly property color live:       "#3ecf6b"
	readonly property color connecting: "#e0b341"
	readonly property color failed:     "#ff4f5e"

	readonly property int gap: 8
}
