#pragma once

#include <memory>
#include <string>

#include "Service.hpp"
#include "Settings.hpp"

namespace pqxx { class connection; }

// Reads the HC-12 radio archive on the shared PostgreSQL, one configured statement per poll.
// The archive's layout is one table per signal name, so db-query is where the interesting
// part lives and this class only runs it.
class Database : public Service {
public:
	explicit Database(const Settings& settings);
	~Database() override;

protected:
	void step() override;
	void reset() override;

private:
	std::string dsn() const;

	const Settings&                   m_settings;
	std::unique_ptr<pqxx::connection> m_connection;
};
