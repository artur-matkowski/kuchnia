#include "Database.hpp"

#include <pqxx/pqxx>

#include "Log.hpp"

namespace {

// libpq's connection string is space-separated keyword=value, so a password containing a
// space silently ends the value and turns the rest into unrecognised keywords - which
// reports as a connection error naming a keyword nobody wrote.
std::string quoted(const std::string& value)
{
	std::string out = "'";
	for (const char c : value) {
		if (c == '\\' || c == '\'')
			out += '\\';
		out += c;
	}
	out += "'";
	return out;
}

}  // namespace

Database::Database(const Settings& settings)
	: Service(applog::Db, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
{
}

Database::~Database()
{
	stop();
}

std::string Database::dsn() const
{
	// connect_timeout is not optional here: without it a host that drops packets rather
	// than refusing them parks this thread in connect() indefinitely, and the service looks
	// hung rather than failing.
	return "host=" + quoted(m_settings.dbHost) +
	       " port=" + quoted(std::to_string(m_settings.dbPort)) +
	       " dbname=" + quoted(m_settings.dbName) +
	       " user=" + quoted(m_settings.dbUser) +
	       " password=" + quoted(m_settings.dbPassword) +
	       " connect_timeout=5";
}

void Database::reset()
{
	m_connection.reset();
}

void Database::step()
{
	if (!m_connection) {
		m_connection = std::make_unique<pqxx::connection>(dsn());
		LOG_INFO(topic()) << "connected to " << m_settings.dbName << " at "
		                  << m_settings.dbHost << ":" << m_settings.dbPort
		                  << " as " << m_settings.dbUser;
	}

	pqxx::work transaction(*m_connection);
	const pqxx::result rows = transaction.exec(m_settings.dbQuery);
	transaction.commit();

	LOG_INFO(topic()) << rows.size() << " row(s)";
	for (const auto& row : rows) {
		applog::Line line(debug::LogLevel::Info, topic());
		line << " ";
		for (pqxx::row::size_type column = 0; column < row.size(); ++column)
			line << " " << rows.column_name(column) << "="
			     << (row[column].is_null() ? "NULL" : row[column].c_str());
	}

	waitFor(m_settings.dbIntervalMs);
}
