import QtQuick
import QtQuick.Layouts
import Kuchnia

// Cloud cover over time, split by altitude - the density half of the layers/density pair
// CloudLayersCard draws the "now" half of. Three overlaid series sharing one 0-100% axis,
// through the same window ForecastSpan drives every other forecast chart with.
Card {
	id: root

	title: "Zachmurzenie"
	status: Weather.status

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		// A static literal model, built once and never touched again - not the mutable-list
		// Repeater docs/charts.md warns against, any more than a `states: [...]` block is.
		RowLayout {
			Layout.fillHeight: false
			spacing: Theme.gap * 2

			Repeater {
				model: [
					{ label: "Niskie", color: Theme.cloudLow },
					{ label: "Średnie", color: Theme.cloudMid },
					{ label: "Wysokie", color: Theme.cloudHigh }
				]

				RowLayout {
					spacing: Theme.gap / 2
					Rectangle { width: 14; height: 14; radius: 3; color: modelData.color }
					Text {
						text: modelData.label
						color: Theme.textDim
						font.pixelSize: Theme.fontLabel
					}
				}
			}
		}

		OverlayChart {
			id: chart
			Layout.fillWidth: true
			Layout.fillHeight: true
			rightGutter: true
			bands: Weather.daylight
			fixedLow: 0
			fixedHigh: 100
			unit: "%"
			decimals: 0
			series: [
				{ data: Weather.cloudCoverLowForecast,  stroke: Theme.cloudLow },
				{ data: Weather.cloudCoverMidForecast,  stroke: Theme.cloudMid },
				{ data: Weather.cloudCoverHighForecast, stroke: Theme.cloudHigh }
			]
		}
	}

	// See ChartCard.qml: ONE Binding, gated on visibility, RestoreNone - two of either
	// reintroduces the 4.5 second freeze docs/charts.md describes.
	Binding {
		target: chart; property: "window"
		value: ForecastSpan.window
		when: chart.visible
		restoreMode: Binding.RestoreNone
	}
}
