import QtQuick
import QtHmi

Card {
	id: root

	title: "Weather"
	status: Weather.status
	statusDetail: Weather.statusDetail

	Column {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			id: reading
			text: Weather.live
			      ? Weather.temperature.toFixed(1) + "°C   " + Weather.humidity.toFixed(0) + "%   wmo " + Weather.weatherCode
			      : "--"
			color: Weather.live ? Theme.text : Theme.textDim
			font.pixelSize: 20
			font.bold: true
		}

		LineChart {
			width: parent.width
			height: (parent.height - parent.spacing * 2 - reading.height) / 2
			series: Weather.temperatureForecast
			stroke: Theme.cool
			unit: "°"
			minimumSpan: 5
		}

		LineChart {
			width: parent.width
			height: (parent.height - parent.spacing * 2 - reading.height) / 2
			series: Weather.precipitationForecast
			stroke: Theme.accent
			unit: "%"
			decimals: 0
			minimumSpan: 10
		}
	}
}
