import QtQuick
import Kuchnia

Card {
	id: root

	title: "Hot water"
	status: HotWater.status
	statusDetail: HotWater.statusDetail

	// The tank's working range, and it is the same number on the gauge and on the chart: two
	// readings of one tank that disagree about their scale are read as two different tanks.
	readonly property real minimumTemperature: 20
	readonly property real maximumTemperature: 65

	Row {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Gauge {
			width: Math.min(parent.width * 0.4, parent.height)
			height: parent.height
			value: HotWater.current
			valid: HotWater.live
			minimum: root.minimumTemperature
			maximum: root.maximumTemperature
			unit: "°"
			arc: Theme.hot
		}

		LineChart {
			width: parent.width - parent.spacing - Math.min(parent.width * 0.4, parent.height)
			height: parent.height
			series: HotWater.history
			stroke: Theme.hot
			unit: "°"
			decimals: 0
			fixedLow: root.minimumTemperature
			fixedHigh: root.maximumTemperature
		}
	}
}
