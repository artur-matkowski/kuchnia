#include "Http.hpp"

#include <memory>
#include <stdexcept>

#include <Poco/StreamCopier.h>
#include <Poco/URI.h>
#include <Poco/Net/Context.h>
#include <Poco/Net/HTTPClientSession.h>
#include <Poco/Net/HTTPRequest.h>
#include <Poco/Net/HTTPResponse.h>
#include <Poco/Net/HTTPSClientSession.h>
#include <Poco/Net/RejectCertificateHandler.h>
#include <Poco/Net/SSLManager.h>

#include "Log.hpp"

namespace {

std::unique_ptr<Poco::Net::HTTPClientSession> openSession(const Poco::URI& uri, const char* setting)
{
	const std::string scheme = uri.getScheme();
	const unsigned short port = uri.getPort();

	if (scheme == "https")
		return std::make_unique<Poco::Net::HTTPSClientSession>(uri.getHost(), port);
	if (scheme == "http")
		return std::make_unique<Poco::Net::HTTPClientSession>(uri.getHost(), port);

	throw std::runtime_error(std::string(setting) + " scheme '" + scheme +
	                         "' is neither http nor https");
}

}  // namespace

namespace http {

void initializeTls()
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

void shutdownTls()
{
	Poco::Net::uninitializeSSL();
}

std::string get(const std::string& url, const char* setting, const char* topic)
{
	const Poco::URI uri(url);
	std::string path = uri.getPathAndQuery();
	if (path.empty())
		path = "/";

	const std::unique_ptr<Poco::Net::HTTPClientSession> session = openSession(uri, setting);
	session->setTimeout(Poco::Timespan(10, 0));

	Poco::Net::HTTPRequest request(Poco::Net::HTTPRequest::HTTP_GET, path,
	                               Poco::Net::HTTPMessage::HTTP_1_1);
	request.set("User-Agent", "kuchnia");
	session->sendRequest(request);

	Poco::Net::HTTPResponse response;
	std::istream& stream = session->receiveResponse(response);
	std::string body;
	Poco::StreamCopier::copyToString(stream, body);

	if (response.getStatus() != Poco::Net::HTTPResponse::HTTP_OK)
		throw std::runtime_error("GET " + url + " (" + setting + ") returned " +
		                         std::to_string(response.getStatus()) + " " + response.getReason());

	LOG_INFO(topic) << "GET " << uri.getHost() << path << " -> 200, " << body.size() << " bytes";
	return body;
}

}  // namespace http
