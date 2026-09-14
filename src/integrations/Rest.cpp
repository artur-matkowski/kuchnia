#include "Rest.hpp"

#include <algorithm>
#include <cstdio>
#include <ctime>
#include <stdexcept>
#include <utility>
#include <vector>

#include <Poco/JSON/Array.h>
#include <Poco/JSON/Object.h>
#include <Poco/JSON/Parser.h>
#include <Poco/URI.h>

#include "Http.hpp"
#include "Log.hpp"

namespace {

double number(const Poco::JSON::Object::Ptr& object, const char* key)
{
	if (!object || !object->has(key) || object->isNull(key))
		return 0.0;
	return object->getValue<double>(key);
}

// open-meteo timestamps are "2026-08-19T05:00" with no zone, and the query asks for no
// timezone, so they are UTC. timegm rather than mktime: mktime would read them as local time
// and slide the whole forecast by the machine's offset - a chart that looks entirely
// plausible and is drawn hours away from where it belongs.
double epochOf(const std::string& iso)
{
	std::tm parts = {};
	if (sscanf(iso.c_str(), "%d-%d-%dT%d:%d", &parts.tm_year, &parts.tm_mon, &parts.tm_mday,
	           &parts.tm_hour, &parts.tm_min) != 5)
		return 0.0;
	parts.tm_year -= 1900;
	parts.tm_mon -= 1;
	return static_cast<double>(timegm(&parts));
}

// One hourly.<key> array zipped against hourly.time. open-meteo pads a series it has no data
// for with nulls rather than shortening it, so a null is skipped and not read as a zero.
Series hourly(const Poco::JSON::Object::Ptr& block, const char* key)
{
	Series series;
	if (!block || !block->isArray("time") || !block->isArray(key))
		return series;

	const Poco::JSON::Array::Ptr times = block->getArray("time");
	const Poco::JSON::Array::Ptr values = block->getArray(key);
	const std::size_t count = std::min(times->size(), values->size());

	series.reserve(count);
	for (std::size_t i = 0; i < count; ++i) {
		if (values->isNull(static_cast<unsigned>(i)))
			continue;
		const double at = epochOf(times->getElement<std::string>(static_cast<unsigned>(i)));
		if (at > 0.0)
			series.push_back({at, values->getElement<double>(static_cast<unsigned>(i))});
	}
	return series;
}

// daily.sunrise zipped against daily.sunset. Both are ISO stamps with no zone, like the
// hourly ones, and are read as UTC for the same reason. A day where either end is null - a
// polar summer, which open-meteo pads rather than shortens - is skipped whole, because half
// a band is a band that ends at 1970.
std::vector<Daylight> daylight(const Poco::JSON::Object::Ptr& block)
{
	std::vector<Daylight> bands;
	if (!block || !block->isArray("sunrise") || !block->isArray("sunset"))
		return bands;

	const Poco::JSON::Array::Ptr sunrise = block->getArray("sunrise");
	const Poco::JSON::Array::Ptr sunset = block->getArray("sunset");
	const std::size_t count = std::min(sunrise->size(), sunset->size());

	bands.reserve(count);
	for (std::size_t i = 0; i < count; ++i) {
		const unsigned at = static_cast<unsigned>(i);
		if (sunrise->isNull(at) || sunset->isNull(at))
			continue;
		const Daylight band = {epochOf(sunrise->getElement<std::string>(at)),
		                       epochOf(sunset->getElement<std::string>(at))};
		if (band.from > 0.0 && band.to > band.from)
			bands.push_back(band);
	}
	return bands;
}

// The whole query beyond the coordinates, and the only place it is written: parseForecast()
// below reads exactly these names. A field is added here and there, never in a config file -
// a config default reaches only a file that does not exist yet. forecast_days is 8 and not 7,
// and no timezone is ever asked for; docs/rest.md says why for both.
constexpr const char* kForecastFields =
	"current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,"
	"wind_direction_10m,cloud_cover,rain,snowfall"
	"&hourly=temperature_2m,precipitation_probability,cloud_cover_low,cloud_cover_mid,"
	"cloud_cover_high,visibility,relative_humidity_2m,rain,snowfall"
	"&daily=sunrise,sunset&forecast_days=8";

// rest-url with the fields above appended. One that names any of them itself is refused rather
// than merged: open-meteo unions a repeated parameter, so a stale list in a config file would
// ride along unnoticed, and a timezone would slide every timestamp.
std::string forecastUrl(const std::string& configured)
{
	const Poco::URI uri(configured);
	for (const auto& parameter : uri.getQueryParameters()) {
		const std::string& name = parameter.first;
		if (name == "current" || name == "hourly" || name == "daily" ||
		    name == "forecast_days" || name == "timezone")
			throw std::runtime_error("rest-url carries " + name + "= - the client asks for its "
			                         "own fields, so leave only latitude and longitude there");
	}
	return configured + (configured.find('?') == std::string::npos ? "?" : "&") + kForecastFields;
}

WeatherUpdate parseForecast(const char* topic, const std::string& body)
{
	Poco::JSON::Parser parser;
	const Poco::JSON::Object::Ptr root = parser.parse(body).extract<Poco::JSON::Object::Ptr>();
	const Poco::JSON::Object::Ptr current = root->getObject("current");

	if (!current || !current->has("temperature_2m"))
		throw std::runtime_error("no current.temperature_2m in the response - check rest-url");

	WeatherUpdate update;
	update.temperature   = number(current, "temperature_2m");
	update.humidity      = number(current, "relative_humidity_2m");
	update.weatherCode   = static_cast<int>(number(current, "weather_code"));
	update.windSpeed     = number(current, "wind_speed_10m");
	update.windDirection = number(current, "wind_direction_10m");
	update.cloudCover    = number(current, "cloud_cover");
	update.rain          = number(current, "rain");
	update.snowfall      = number(current, "snowfall");

	const Poco::JSON::Object::Ptr block = root->getObject("hourly");
	update.temperatureForecast    = hourly(block, "temperature_2m");
	update.precipitationForecast  = hourly(block, "precipitation_probability");
	update.rainForecast           = hourly(block, "rain");
	update.snowForecast           = hourly(block, "snowfall");
	update.humidityForecast       = hourly(block, "relative_humidity_2m");
	update.cloudCoverLowForecast  = hourly(block, "cloud_cover_low");
	update.cloudCoverMidForecast  = hourly(block, "cloud_cover_mid");
	update.cloudCoverHighForecast = hourly(block, "cloud_cover_high");
	update.visibilityForecast     = hourly(block, "visibility");
	update.daylight               = daylight(root->getObject("daily"));

	LOG_INFO(topic) << "temperature " << update.temperature << " C, humidity "
	                << update.humidity << " %, code " << update.weatherCode << ", wind "
	                << update.windSpeed << " km/h from " << update.windDirection << " deg, cloud "
	                << update.cloudCover << " %, " << update.temperatureForecast.size()
	                << " forecast point(s), " << update.daylight.size() << " daylight band(s)";
	return update;
}

}  // namespace

Rest::Rest(const Settings& settings, Sinks sinks)
	: Service(applog::Rest, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
	, m_sinks(std::move(sinks))
{
}

Rest::~Rest()
{
	stop();
}

void Rest::step()
{
	const std::string body = http::get(forecastUrl(m_settings.restUrl), "rest-url", topic());

	const WeatherUpdate update = parseForecast(topic(), body);
	reportHealth(Health::Live);
	if (m_sinks.weather)
		m_sinks.weather(update);

	waitFor(m_settings.restIntervalMs);
}
