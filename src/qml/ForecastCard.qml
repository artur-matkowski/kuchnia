import QtQuick
import Kuchnia

// The temperature forecast, drawn through the window ForecastSpan owns.
//
// Its own file because two things draw it: the card that migrates between the compact and
// weather screens, and the second instance the carousel needs so that both of those
// miniatures can show one at the same time. A copy of the configuration in each would be two
// homes for one fact - a series or a range changed in one and not the other is two charts
// that disagree about the same weather.
ChartCard {
	title: ForecastSpan.label ? "Forecast · " + ForecastSpan.label : "Forecast"
	series: Weather.temperatureForecast
	stroke: Theme.cool
	unit: "°"
	decimals: 0
	minimumSpan: 5
}
