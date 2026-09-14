import QtQuick
import QtQuick.Layouts
import Kuchnia

// Rain, snow and humidity in one chart: two lines sharing a left mm/cm axis, humidity as
// spikes against a right percent axis. The left axis is literal, not converted - a "2" reads
// the same height whether it means 2 mm of rain or 2 cm of snow, and the two are told apart by
// colour through the legend below, not by the axis.
Card {
	id: root

	title: "Deszcz, śnieg i wilgotność"
	status: Weather.status

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		RowLayout {
			Layout.fillHeight: false
			spacing: Theme.gap * 2

			Repeater {
				model: [
					{ label: "Deszcz", color: Theme.rain },
					{ label: "Śnieg", color: Theme.snow },
					{ label: "Wilgotność", color: Theme.humidity }
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

		DualAxisChart {
			id: chart
			Layout.fillWidth: true
			Layout.fillHeight: true
			bands: Weather.daylight
			leftAxis:  ({ fixedLow: 0, minimumSpan: 2, unit: "mm", decimals: 1 })
			rightAxis: ({ fixedLow: 0, fixedHigh: 100, unit: "%", decimals: 0 })
			series: [
				{ data: Weather.rainForecast,     stroke: Theme.rain,     kind: "line",  axis: "left"  },
				{ data: Weather.snowForecast,     stroke: Theme.snow,     kind: "line",  axis: "left"  },
				{ data: Weather.humidityForecast, stroke: Theme.humidity, kind: "spike", axis: "right" }
			]
		}
	}

	Binding {
		target: chart; property: "window"
		value: ForecastSpan.window
		when: chart.visible
		restoreMode: Binding.RestoreNone
	}
}
