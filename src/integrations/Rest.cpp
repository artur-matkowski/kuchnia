#include "Rest.hpp"

#include <algorithm>
#include <cstdio>
#include <ctime>
#include <memory>
#include <stdexcept>
#include <utility>

#include <Poco/JSON/Array.h>
#include <Poco/StreamCopier.h>
#include <Poco/URI.h>
#include <Poco/JSON/Object.h>
#include <Poco/JSON/Parser.h>
#include <Poco/Net/Context.h>
#include <Poco/Net/HTTPClientSession.h>
#include <Poco/Net/HTTPRequest.h>
#include <Poco/Net/HTTPResponse.h>
#include <Poco/Net/HTTPSClientSession.h>
#include <Poco/Net/RejectCertificateHandler.h>
#include <Poco/Net/SSLManager.h>

#include "Log.hpp"

namespace {

std::unique_ptr<Poco::Net::HTTPClientSession> openSession(const Poco::URI& uri)
{
	const std::string scheme = uri.getScheme();
	const unsigned short port = uri.getPort();

	if (scheme == "https")
		return std::make_unique<Poco::Net::HTTPSClientSession>(uri.getHost(), port);
	if (scheme == "http")
		return std::make_unique<Poco::Net::HTTPClientSession>(uri.getHost(), port);

	throw std::runtime_error("rest-url scheme '" + scheme + "' is neither http nor https");
}

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

WeatherUpdate parseForecast(const char* topic, const std::string& body)
{
	Poco::JSON::Parser parser;
	const Poco::JSON::Object::Ptr root = parser.parse(body).extract<Poco::JSON::Object::Ptr>();
	const Poco::JSON::Object::Ptr current = root->getObject("current");

	if (!current || !current->has("temperature_2m"))
		throw std::runtime_error("no current.temperature_2m in the response - check rest-url");

	WeatherUpdate update;
	update.temperature = number(current, "temperature_2m");
	update.humidity    = number(current, "relative_humidity_2m");
	update.weatherCode = static_cast<int>(number(current, "weather_code"));

	const Poco::JSON::Object::Ptr block = root->getObject("hourly");
	update.temperatureForecast   = hourly(block, "temperature_2m");
	update.precipitationForecast = hourly(block, "precipitation_probability");

	LOG_INFO(topic) << "temperature " << update.temperature << " C, humidity "
	                << update.humidity << " %, code " << update.weatherCode << ", "
	                << update.temperatureForecast.size() << " forecast point(s)";
	return update;
}

}  // namespace

void Rest::initializeTls()
{
	Poco::Net::initializeSSL();

	// VERIFY_RELAXED with the system trust store, and a handler that rejects rather than
	// prompts: an unattended board has nobody to ask. A missing CA bundle therefore fails
	// the request loudly instead of trusting whatever answered.
	const Poco::SharedPtr<Poco::Net::InvalidCertificateHandler> handler =
		new Poco::Net::RejectCertificateHandler(false);
	const Poco::Net::Context::Ptr context = new Poco::Net::Context(
		Poco::Net::Context::TLS_CLIENT_USE, "", Poco::Net::Context::VERIFY_RELAXED, 9, true);

	Poco::Net::SSLManager::instance().initializeClient(nullptr, handler, context);
}

void Rest::shutdownTls()
{
	Poco::Net::uninitializeSSL();
}

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
	const Poco::URI uri(m_settings.restUrl);
	std::string path = uri.getPathAndQuery();
	if (path.empty())
		path = "/";

	const std::unique_ptr<Poco::Net::HTTPClientSession> session = openSession(uri);
	session->setTimeout(Poco::Timespan(10, 0));

	Poco::Net::HTTPRequest request(Poco::Net::HTTPRequest::HTTP_GET, path,
	                               Poco::Net::HTTPMessage::HTTP_1_1);
	request.set("User-Agent", "qt-hmi");
	session->sendRequest(request);

	Poco::Net::HTTPResponse response;
	std::istream& stream = session->receiveResponse(response);
	std::string body;
	Poco::StreamCopier::copyToString(stream, body);

	if (response.getStatus() != Poco::Net::HTTPResponse::HTTP_OK)
		throw std::runtime_error("GET " + m_settings.restUrl + " returned " +
		                         std::to_string(response.getStatus()) + " " + response.getReason());

	LOG_INFO(topic()) << "GET " << uri.getHost() << path << " -> 200, " << body.size() << " bytes";

	const WeatherUpdate update = parseForecast(topic(), body);
	reportHealth(Health::Live);
	if (m_sinks.weather)
		m_sinks.weather(update);

	waitFor(m_settings.restIntervalMs);
}
