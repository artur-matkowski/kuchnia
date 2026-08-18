#include "Integrations.hpp"

#include "Database.hpp"
#include "Log.hpp"
#include "Mqtt.hpp"
#include "Rest.hpp"

Integrations::Integrations(const Settings& settings)
{
	Rest::initializeTls();

	m_database = std::make_unique<Database>(settings);
	m_rest     = std::make_unique<Rest>(settings);
	m_mqtt     = std::make_unique<Mqtt>(settings);

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
