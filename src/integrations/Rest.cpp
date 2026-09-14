#include "Rest.hpp"

#include <algorithm>
#include <cstdio>
#include <ctime>
#include <iterator>
#include <stdexcept>
#include <string>
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

// The pressure levels the cloud column is read at, ground up; above 200 hPa there is no cloud
// over the board. Each is two hourly fields, asked for and read from this one table.
constexpr int kCloudLevels[] = {1000, 975, 950, 925, 900, 850, 800, 700, 600, 500, 400, 300, 250, 200};

// ICM's coverage thresholds for a cloud base, in octas, laxest first. The legend in
// CloudLayersCard.qml and Theme.cloudBase follow this order and length - see docs/rest.md.
constexpr double kCloudBaseOktas[] = {0.1, 2.5, 4.5, 6.5, 7.9};

std::string levelKey(const char* quantity, int level)
{
	return quantity + std::to_string(level) + "hPa";
}

// The column over the board, hour by hour: for each threshold the lowest level whose cover
// passes it, the highest level past the laxest one, and every hour the column was whole.
// Read by index, never through hourly(): that skips nulls, and one level shortened by a null
// would pair every later hour with another hour's cover - see docs/rest.md.
void cloudProfile(const Poco::JSON::Object::Ptr& block, double elevation, WeatherUpdate& update)
{
	update.cloudBaseForecast.assign(std::size(kCloudBaseOktas), Series());
	if (!block || !block->isArray("time"))
		return;

	std::vector<std::pair<Poco::JSON::Array::Ptr, Poco::JSON::Array::Ptr>> levels;
	for (const int level : kCloudLevels) {
		const std::string cover = levelKey("cloud_cover_", level);
		const std::string height = levelKey("geopotential_height_", level);
		if (!block->isArray(cover) || !block->isArray(height))
			return;
		levels.emplace_back(block->getArray(cover), block->getArray(height));
	}

	struct Layer {
		double cover;  // percent
		double km;     // above sea level
	};

	const Poco::JSON::Array::Ptr times = block->getArray("time");
	for (unsigned at = 0; at < times->size(); ++at) {
		const double time = epochOf(times->getElement<std::string>(at));
		if (time <= 0.0)
			continue;

		// A level at or under the ground - 1000 hPa in a low - holds extrapolated cloud that
		// would draw as fog, so it is left out of the column rather than failing the hour.
		std::vector<Layer> column;
		bool whole = true;
		for (const auto& [cover, height] : levels) {
			if (at >= cover->size() || at >= height->size() || cover->isNull(at) ||
			    height->isNull(at)) {
				whole = false;
				break;
			}
			const double metres = height->getElement<double>(at);
			if (metres > elevation)
				column.push_back({cover->getElement<double>(at), metres / 1000.0});
		}
		if (!whole)
			continue;

		update.cloudProfileHours.push_back({time, static_cast<double>(column.size())});
		for (std::size_t k = 0; k < std::size(kCloudBaseOktas); ++k) {
			const auto base = std::find_if(column.begin(), column.end(), [k](const Layer& layer) {
				return layer.cover > kCloudBaseOktas[k] * 12.5;
			});
			if (base != column.end())
				update.cloudBaseForecast[k].push_back({time, base->km});
		}
		const auto top = std::find_if(column.rbegin(), column.rend(), [](const Layer& layer) {
			return layer.cover > kCloudBaseOktas[0] * 12.5;
		});
		if (top != column.rend())
			update.cloudTopForecast.push_back({time, top->km});
	}
}

// The whole query beyond the coordinates, and the only place it is written: parseForecast()
// and cloudProfile() read exactly these names. A field is added here and there, never in a
// config file - a config default reaches only a file that does not exist yet. forecast_days
// is 8 and not 7, and no timezone is ever asked for; docs/rest.md says why for both.
std::string forecastFields()
{
	std::string fields = "temperature_2m,precipitation_probability,cloud_cover_low,cloud_cover_mid,"
	                     "cloud_cover_high,visibility,relative_humidity_2m,rain,snowfall";
	for (const int level : kCloudLevels)
		fields += "," + levelKey("cloud_cover_", level) + "," + levelKey("geopotential_height_", level);

	return "current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,"
	       "wind_direction_10m,cloud_cover,rain,snowfall&hourly=" + fields +
	       "&daily=sunrise,sunset&forecast_days=8";
}

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
	return configured + (configured.find('?') == std::string::npos ? "?" : "&") + forecastFields();
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
	cloudProfile(block, number(root, "elevation"), update);

	LOG_INFO(topic) << "temperature " << update.temperature << " C, humidity "
	                << update.humidity << " %, code " << update.weatherCode << ", wind "
	                << update.windSpeed << " km/h from " << update.windDirection << " deg, cloud "
	                << update.cloudCover << " %, " << update.temperatureForecast.size()
	                << " forecast point(s), " << update.cloudProfileHours.size()
	                << " cloud profile hour(s), " << update.daylight.size() << " daylight band(s)";
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
