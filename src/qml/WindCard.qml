import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Kuchnia

// Wind speed, and where it is coming from.
//
// THE ARROW POINTS THE WAY THE WIND IS BLOWING; THE WORDS SAY WHERE IT IS BLOWING FROM. Those
// are opposite directions and both readings are conventional - a weather vane names the
// source, an arrow drawn on a map names the destination. windDirection is the meteorological
// one, degrees the wind comes FROM, so the needle is turned by half a circle on top of it.
// Drop that and the card is wrong by 180 degrees in a way nothing on screen contradicts.
Card {
	id: root

	title: "Wind"
	status: Weather.status

	// Eight points and not sixteen: NNW is two more glyphs and no more information at the
	// distance this is read from.
	function _from(degrees) {
		var names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
		return names[Math.round(((degrees % 360) + 360) % 360 / 45) % 8]
	}

	RowLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap * 2

		Item {
			id: rose
			Layout.fillHeight: true
			Layout.preferredWidth: height

			readonly property real cx: width / 2
			readonly property real cy: height / 2
			readonly property real radius: Math.min(width, height) * 0.42

			Shape {
				anchors.fill: parent

				ShapePath {
					strokeColor: Theme.border
					strokeWidth: 3
					fillColor: "transparent"
					PathAngleArc {
						centerX: rose.cx
						centerY: rose.cy
						radiusX: rose.radius
						radiusY: rose.radius
						startAngle: 0
						sweepAngle: 360
					}
				}
			}

			Text {
				anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
				text: "N"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}

			// Nothing is drawn without a reading. A needle parked at north is a plausible
			// direction, and the status badge is too small to be read as a correction to it.
			Item {
				anchors.fill: parent
				visible: Weather.live
				rotation: Weather.windDirection + 180

				Shape {
					anchors.fill: parent

					ShapePath {
						strokeColor: Theme.accent
						strokeWidth: Math.max(4, rose.radius * 0.12)
						fillColor: "transparent"
						capStyle: ShapePath.RoundCap
						joinStyle: ShapePath.RoundJoin

						startX: rose.cx
						startY: rose.cy + rose.radius * 0.6
						PathLine { x: rose.cx; y: rose.cy - rose.radius * 0.6 }
						PathMove { x: rose.cx - rose.radius * 0.28; y: rose.cy - rose.radius * 0.28 }
						PathLine { x: rose.cx; y: rose.cy - rose.radius * 0.6 }
						PathLine { x: rose.cx + rose.radius * 0.28; y: rose.cy - rose.radius * 0.28 }
					}
				}
			}
		}

		// The caption sits beside the number rather than under it. Stacked, this column is
		// taller than Theme.readingRow and the card clips its own last line - which is the line
		// saying which way the wind is coming from.
		Text {
			text: Weather.live ? Weather.windSpeed.toFixed(0) : "--"
			color: Weather.live ? Theme.text : Theme.textDim
			font.pixelSize: Theme.fontHero
			font.bold: true
		}

		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2

			Text {
				text: "km/h"
				color: Theme.textDim
				font.pixelSize: Theme.fontBody
			}

			Text {
				visible: Weather.live
				text: "from " + root._from(Weather.windDirection)
				color: Theme.text
				font.pixelSize: Theme.fontBody
			}
		}
	}
}
