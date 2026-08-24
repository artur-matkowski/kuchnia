import QtQuick
import QtQuick.Layouts
import Kuchnia

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
		}
	}

	// The window is bound only while the card can be seen. Four of the scene's six charts are
	// off screen at any moment - the two on whichever forecast screen is not showing, and the
	// carousel's two copies - and an invisible item stops rendering but does not stop
	// evaluating: each of them would remap its series once per frame of a span change for
	// something nobody is looking at.
	//
	// RestoreNone leaves the parked window in place instead of reverting it to zero. The
	// binding is back on the frame opacity first rises above zero, which is before the card
	// has been drawn, so a chart never arrives showing the span it left on.
	//
	// ONE Binding, and that is not a tidying. Two of them take effect one after the other, so
	// a chart being made visible for the first time - the carousel's copies, and only ever on
	// the first press - had an end and no start for one evaluation: a window from 1970 to next
	// week, and a day grid of twenty thousand lines built on the GUI thread.
	Binding {
		target: chart; property: "window"
		value: ForecastSpan.window
		when: chart.visible
		restoreMode: Binding.RestoreNone
	}
}
