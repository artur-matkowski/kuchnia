import QtQuick
import QtQuick.Layouts
import Kuchnia

// Cloud cover right now, by altitude - three bands, high to low, each filled by that layer's
// share of the sky. The "now" half of the layers/density pair; CloudCoverCard is the
// over-time half, charting the same three series instead of reading one point from each.
//
// Simplified layered bands rather than chmury.png's literal dot-plot: cloud base/top height by
// coverage octant needs a model's raw vertical profile, which is not part of what open-meteo's
// forecast product exposes at any parameter - see the research behind this feature.
Card {
	id: root

	title: "Warstwy chmur"
	status: Weather.status

	readonly property real highValue: _nowValue(Weather.cloudCoverHighForecast)
	readonly property real midValue:  _nowValue(Weather.cloudCoverMidForecast)
	readonly property real lowValue:  _nowValue(Weather.cloudCoverLowForecast)
	readonly property real visibilityKm: _nowValue(Weather.visibilityForecast) / 1000

	// The first point at or after now, or the series' last point if the poll has gone stale
	// and every point is already in the past. Not points[0]: the hourly array starts at today's
	// midnight, not at now, so the un-scanned first element is usually a past hour.
	//
	// This runs inside a binding that also reads a Weather Q_PROPERTY (the caller always reads
	// one of the ...Forecast series above it), so the whole expression re-evaluates on every
	// forecastChanged - each REST poll - and Date.now() is read fresh each time. A bare
	// `property var now: Date.now()` would instead evaluate once at load and freeze forever;
	// see docs/scene.md's Clock.qml pitfall, the same trap with no data dependency to save it.
	function _nowValue(data) {
		if (!data || !data.points || data.points.length === 0)
			return NaN

		const now = Date.now()
		const points = data.points
		for (let i = 0; i < points.length; ++i)
			if (points[i].x >= now)
				return points[i].y
		return points[points.length - 1].y
	}

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Repeater {
			model: [
				{ label: "Wysokie", value: root.highValue, color: Theme.cloudHigh },
				{ label: "Średnie", value: root.midValue,  color: Theme.cloudMid },
				{ label: "Niskie",  value: root.lowValue,  color: Theme.cloudLow }
			]

			Item {
				Layout.fillWidth: true
				Layout.fillHeight: true

				Rectangle {
					anchors.fill: parent
					radius: 4
					color: modelData.color
					opacity: 0.18
				}

				// No fallback reading: a band whose series is empty stays unfilled and says
				// "brak danych" rather than drawing a plausible-looking 0% - see docs/state.md.
				Rectangle {
					readonly property bool valid: !isNaN(modelData.value)
					anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
					width: valid ? Math.max(0, parent.width * modelData.value / 100) : 0
					radius: 4
					color: modelData.color
				}

				Text {
					anchors.centerIn: parent
					text: isNaN(modelData.value)
						? modelData.label + " · brak danych"
						: modelData.label + " · " + modelData.value.toFixed(0) + "%"
					color: Theme.text
					font.pixelSize: Theme.fontBody
					font.bold: true
				}
			}
		}

		Text {
			Layout.fillHeight: false
			visible: !isNaN(root.visibilityKm)
			text: "Widoczność: " + root.visibilityKm.toFixed(0) + " km"
			color: Theme.textDim
			font.pixelSize: Theme.fontLabel
		}
	}
}
