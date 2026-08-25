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

// A stretch of daylight, sunrise to sunset, in seconds since the epoch like Sample. The
// conversion to the milliseconds QML wants happens at the seam in src/app/, once.
struct Daylight {
	double from = 0.0;
	double to   = 0.0;
};

struct HotWaterUpdate {
	double current = 0.0;  // degrees Celsius
	Series history;
};

struct WeatherUpdate {
	double temperature   = 0.0;  // degrees Celsius
	double humidity      = 0.0;  // percent
	int    weatherCode   = 0;    // WMO code
	double windSpeed     = 0.0;  // km/h
	double windDirection = 0.0;  // degrees, meteorological: the direction it blows FROM
	double cloudCover    = 0.0;  // percent
	double rain          = 0.0;  // millimetres in the last hour
	double snowfall      = 0.0;  // centimetres in the last hour

	Series temperatureForecast;

	// Two precipitation series in two units, and only the names keep them apart: one is the
	// chance of rain and is pinned to 0-100, the other is how much falls. Charted against the
	// wrong scale either reads as an entirely plausible forecast of the other thing.
	Series precipitationForecast;        // percent probability
	Series precipitationAmountForecast;  // millimetres per hour, rain and snow together

	Series cloudCoverForecast;  // percent

	// Empty when the query did not ask for the daily block: the charts then draw no bands,
	// which is the same silent omission every other field here has.
	std::vector<Daylight> daylight;
};

// One person sharing a location, as the location service reports them.
//
// `id` is that service's own stable key for the person, and it is load-bearing: the model in
// src/app/ matches incoming rows against it, so somebody who has moved is a row that changed
// rather than a list that was thrown away and rebuilt. An id that is not stable between
// polls turns every marker on the map into a new marker, which reads as a flicker and costs
// a full delegate rebuild each time.
struct Person {
	std::string id;
	std::string name;

	double latitude  = 0.0;  // degrees
	double longitude = 0.0;  // degrees
	double accuracy  = 0.0;  // metres, the radius the fix is good to

	// Seconds since the epoch, like Sample - not milliseconds. The conversion to what QML
	// wants happens at the seam in src/app/, once.
	double seenAt = 0.0;

	// Percent, or -1 when the service reported none. Out of range on purpose: a phone at 0%
	// and a phone that did not say are different things, and a default of 0 would draw the
	// second as the first.
	int battery = -1;
};

// Everyone the service currently knows about, in one update. A person who stopped sharing
// leaves by being absent from the next one; the list is the whole truth each time and is
// never merged with what came before.
struct PeopleUpdate {
	std::vector<Person> people;
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
	std::function<void(const PeopleUpdate&)>   people;

	// The bare signal name from hc12/rx/<name> - GateOpened, GateClosing and so on.
	std::function<void(const std::string&)> gateState;

	// topic is one of applog's, which is what routes it to the right panel; detail carries
	// the exception text and is empty when there is nothing wrong.
	std::function<void(const char* topic, Health, const std::string& detail)> health;
};
