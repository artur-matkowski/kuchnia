#pragma once

#include <functional>
#include <string>
#include <vector>

// The one-way channel from the network clients to the scene.
//
// Everything here is plain C++ on purpose. A service must not know that a Qt object is on
// the other end, and the facade in src/app/ must not know about pqxx, Poco or paho - this
// header is the whole of what they agree on.
//
// EVERY CALLBACK RUNS ON THE WORKER THREAD THAT PRODUCED THE DATA. The receiver is
// responsible for getting itself onto the GUI thread before it touches anything Qt owns;
// see src/app/AppState.cpp, where that happens exactly once for all of them.

// A point in a time series: seconds since the epoch, and a value in whatever unit the
// series is about. Not milliseconds - QML's Date takes milliseconds and the conversion is
// done at the seam, once.
struct Sample {
	double time  = 0.0;
	double value = 0.0;
};

using Series = std::vector<Sample>;

struct HotWaterUpdate {
	double current = 0.0;  // degrees Celsius
	Series history;
};

struct WeatherUpdate {
	double temperature = 0.0;  // degrees Celsius
	double humidity    = 0.0;  // percent
	int    weatherCode = 0;    // WMO code
	Series temperatureForecast;
	Series precipitationForecast;  // percent probability
};

// What a panel shows instead of pretending it has data. A service is Failed from the moment
// a step throws until the next one returns, which is what makes a dead LAN visible on the
// screen rather than a chart that has simply stopped moving.
enum class Health {
	Connecting,
	Live,
	Failed,
};

struct Sinks {
	std::function<void(const HotWaterUpdate&)> hotWater;
	std::function<void(const WeatherUpdate&)>  weather;

	// The bare signal name from hc12/rx/<name> - GateOpened, GateClosing and so on.
	std::function<void(const std::string&)> gateState;

	// topic is one of applog's, which is what routes it to the right panel; detail carries
	// the exception text and is empty when there is nothing wrong.
	std::function<void(const char* topic, Health, const std::string& detail)> health;
};
