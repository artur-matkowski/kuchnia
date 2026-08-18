#pragma once

#include <memory>

#include "Settings.hpp"

class Database;
class Mqtt;
class Rest;

// Owns the three services and the process-wide state they share.
//
// Constructing it starts every worker; destroying it stops them all, in the order that lets
// Poco's TLS layer come down after the last session that could still be using it. It holds a
// reference to the settings, which therefore have to outlive it.
class Integrations {
public:
	explicit Integrations(const Settings& settings);
	~Integrations();

	Integrations(const Integrations&) = delete;
	Integrations& operator=(const Integrations&) = delete;

private:
	std::unique_ptr<Database> m_database;
	std::unique_ptr<Rest>     m_rest;
	std::unique_ptr<Mqtt>     m_mqtt;
};
