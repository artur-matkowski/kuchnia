import QtQuick
import QtQuick.Layouts
import Kuchnia

// Where the cloud starts and ends over time, and how far one can see - ICM's "Podstawa chmur o
// pokryciu", drawn through the same window ForecastSpan drives every other forecast chart with.
Card {
	id: root

	title: "Warstwy chmur"
	status: Weather.status

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		RowLayout {
			Layout.fillHeight: false
			spacing: Theme.gap * 2

			Text {
				text: "Podstawa chmur:"
				color: Theme.textDim
				font.pixelSize: Theme.fontLabel
			}

			// kCloudBaseOktas in Rest.cpp, in its order - see docs/rest.md.
			Repeater {
				model: ["> 0.1", "> 2.5", "> 4.5", "> 6.5", "> 7.9 okt"]

				RowLayout {
					spacing: Theme.gap / 2
					Rectangle { width: 14; height: 14; radius: 7; color: Theme.cloudBase[index] }
					Text {
						text: modelData
						color: Theme.textDim
						font.pixelSize: Theme.fontLabel
					}
				}
			}

			RowLayout {
				spacing: Theme.gap / 2
				Rectangle { width: 14; height: 14; radius: 7; color: Theme.cloudTop }
				Text {
					text: "Wierzchołek"
					color: Theme.textDim
					font.pixelSize: Theme.fontLabel
				}
			}

			RowLayout {
				spacing: Theme.gap / 2
				Rectangle { width: 22; height: 3; color: Theme.visibility }
				Text {
					text: "Widzialność"
					color: Theme.textDim
					font.pixelSize: Theme.fontLabel
				}
			}
		}

		CloudBaseChart {
			id: chart
			Layout.fillWidth: true
			Layout.fillHeight: true
			bands: Weather.daylight
			bases: Weather.cloudBaseForecast.map((data, i) => ({ data: data, color: Theme.cloudBase[i] }))
			tops: Weather.cloudTopForecast
			topColor: Theme.cloudTop
			visibility: Weather.visibilityForecast
			visibilityColor: Theme.visibility
			hours: Weather.cloudProfileHours
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
