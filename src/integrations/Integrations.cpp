#include "Integrations.hpp"

#include "Database.hpp"
#include "Log.hpp"
#include "Mqtt.hpp"
#include "Rest.hpp"

Integrations::Integrations(const Settings& settings, Sinks sinks)
{
	Rest::initializeTls();

	m_database = std::make_unique<Database>(settings, sinks);
	m_rest     = std::make_unique<Rest>(settings, sinks);
	m_mqtt     = std::make_unique<Mqtt>(settings, sinks);

	// Before start(), which is the whole contract of setHealthSink: it is written without a
	// lock and read by a thread that does not exist yet.
	m_database->setHealthSink(sinks.health);
	m_rest->setHealthSink(sinks.health);
	m_mqtt->setHealthSink(sinks.health);

	m_database->start();
	m_rest->start();
	m_mqtt->start();

	LOG_INFO(applog::App) << "integrations started: db " << settings.dbHost
	                      << ", rest " << settings.restUrl
	                      << ", mqtt " << settings.mqttHost << ":" << settings.mqttPort;
}

Integrations::~Integrations()
{
	// Explicit and ordered rather than left to the members: every destructor here joins a
	// thread, and the TLS teardown below has to happen after the one that makes requests.
	m_mqtt.reset();
	m_rest.reset();
	m_database.reset();

	Rest::shutdownTls();

	LOG_INFO(applog::App) << "integrations stopped";
}

void Integrations::sendGateCommand(const std::string& command)
{
	m_mqtt->requestGateCommand(command);
}
