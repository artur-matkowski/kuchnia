import QtQuick
import Kuchnia

// The chance of rain, pinned to the whole scale. A probability chart that rescales itself puts
// 40% at the top of the frame, which reads as a downpour from any distance at which the axis
// label cannot be read.
//
// Its own file for the reason ForecastCard.qml is.
ChartCard {
	title: "Szansa opadów"
	series: Weather.precipitationForecast
	stroke: Theme.accent
	unit: "%"
	decimals: 0
	fixedLow: 0
	fixedHigh: 100
}
