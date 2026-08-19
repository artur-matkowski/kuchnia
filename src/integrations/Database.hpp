#pragma once

#include <memory>
#include <string>

#include "Service.hpp"
#include "Settings.hpp"
#include "Sinks.hpp"

namespace pqxx { class connection; }

// Reads the hot water temperature out of the HC-12 radio archive on the shared PostgreSQL.
//
// The archive's layout is one table per signal name, every table (timestamp, idsender,
// idtarget, value). The statements live in the .cpp rather than in the config, because the
// code that reads a result set depends on its column order and a config string can change
// one without the other.
class Database : public Service {
public:
	Database(const Settings& settings, Sinks sinks);
	~Database() override;

protected:
	void step() override;
	void reset() override;

private:
	std::string dsn() const;

	const Settings&                   m_settings;
	Sinks                             m_sinks;
	std::unique_ptr<pqxx::connection> m_connection;
};
