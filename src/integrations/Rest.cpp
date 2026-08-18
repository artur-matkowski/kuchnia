#include "Rest.hpp"

#include <memory>
#include <stdexcept>

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

void reportForecast(const char* topic, const std::string& body)
{
	Poco::JSON::Parser parser;
	const Poco::JSON::Object::Ptr root = parser.parse(body).extract<Poco::JSON::Object::Ptr>();
	const Poco::JSON::Object::Ptr current = root->getObject("current");

	if (!current || !current->has("temperature_2m")) {
		LOG_WARN(topic) << "no current.temperature_2m in the response";
		return;
	}

	applog::Line line(debug::LogLevel::Info, topic);
	line << "temperature " << current->getValue<double>("temperature_2m");
	if (current->has("time"))
		line << " at " << current->getValue<std::string>("time");
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

Rest::Rest(const Settings& settings)
	: Service(applog::Rest, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
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
	reportForecast(topic(), body);

	waitFor(m_settings.restIntervalMs);
}
