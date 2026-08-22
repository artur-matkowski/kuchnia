import QtQuick
import QtQuick.Layouts
import QtHmi

// A card holding one forecast chart, drawn through the shared window in ForecastSpan.
//
// Four of the weather screen's seven cards are this file, two of them arriving from the
// compact screen as ForecastCard and RainChanceCard. What differs between them is a series, a
// colour and a range, and none of that is worth a file each.
Card {
	id: root

	property alias series: chart.series
	property alias stroke: chart.stroke
	property alias unit: chart.unit
	property alias decimals: chart.decimals
	property alias fixedLow: chart.fixedLow
	property alias fixedHigh: chart.fixedHigh
	property alias minimumSpan: chart.minimumSpan

	// The current value of whatever the chart forecasts, already formatted by the caller.
	// Empty draws nothing at all, which is what a caller passes when the panel is not live -
	// there is no fallback reading here and there must not be one.
	property string reading: ""

	// Without the detail: the badge elides against whatever the title leaves, and every chart
	// printing the same connection error is a screen of illegible lines. The temperature card
	// carries the detail for all of them.
	status: Weather.status

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			visible: root.reading.length > 0
			// Explicit, because it defaults to true for a nested layout: left alone this text
			// takes the whole column and the chart is laid out one pixel high.
			Layout.fillHeight: false
			text: root.reading
			color: Theme.text
			font.pixelSize: Theme.fontReading
			font.bold: true
		}

		LineChart {
			id: chart
			Layout.fillWidth: true
			Layout.fillHeight: true
			bands: Weather.daylight
			windowStart: ForecastSpan.windowStart
			windowEnd: ForecastSpan.windowEnd
		}
	}
}
