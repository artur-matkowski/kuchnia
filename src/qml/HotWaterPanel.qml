import QtQuick
import QtHmi

Card {
	id: root

	title: "Hot water"
	status: HotWater.status
	statusDetail: HotWater.statusDetail

	Row {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Gauge {
			width: Math.min(parent.width * 0.4, parent.height)
			height: parent.height
			value: HotWater.current
			valid: HotWater.live
			minimum: 20
			maximum: 80
			unit: "°"
			arc: Theme.hot
		}

		LineChart {
			width: parent.width - parent.spacing - Math.min(parent.width * 0.4, parent.height)
			height: parent.height
			series: HotWater.history
			stroke: Theme.hot
			unit: "°"
			minimumSpan: 5
		}
	}
}
