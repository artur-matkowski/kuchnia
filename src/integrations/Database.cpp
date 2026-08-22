#include "Database.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

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

// CWU is the domestic hot water tank. Its value column is centidegrees - 4668 is 46.68 C -
// which is the single fact about this schema that a reader cannot get from the column names.
const char* const kCurrent =
	"SELECT value / 100.0 FROM \"CWU_temp\" ORDER BY timestamp DESC LIMIT 1";

// The table carries millions of rows and has no index on timestamp, so this is a sequential
// scan every poll and the aggregation has to happen in the server: pulling a day of raw
// samples across the LAN to average them here would move roughly ten thousand rows to draw
// a line a few hundred pixels wide.
//
// The bucket is sized from the window for the same reason, rather than fixed at a minute:
// widening db-history-hours coarsens the line instead of growing the query, the transfer and
// the remap QML does on every poll.
std::string historyQuery(int hours)
{
	const std::string bucket = std::to_string(std::max(60, hours * 3600 / 300));
	return "SELECT floor(extract(epoch FROM timestamp) / " + bucket + ") * " + bucket + " AS t,"
	       " avg(value) / 100.0 AS v"
	       " FROM \"CWU_temp\""
	       " WHERE timestamp > now() - interval '" + std::to_string(hours) + " hours'"
	       " GROUP BY 1 ORDER BY 1";
}

}  // namespace

Database::Database(const Settings& settings, Sinks sinks)
	: Service(applog::Db, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
	, m_sinks(std::move(sinks))
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
	const pqxx::result current = transaction.exec(kCurrent);
	const pqxx::result history = transaction.exec(historyQuery(std::max(1, m_settings.dbHistoryHours)));
	transaction.commit();

	// An archive that has stopped being written is not an error and libpqxx will not report
	// one; the tank simply has no reading, and the scene has to say so rather than draw a
	// zero. Same for a history window that no sample falls into.
	if (current.empty() || current[0][0].is_null())
		throw std::runtime_error("CWU_temp is empty - no hot water reading exists");

	HotWaterUpdate update;
	update.current = current[0][0].as<double>();
	update.history.reserve(history.size());
	for (const auto& row : history)
		update.history.push_back({row[0].as<double>(), row[1].as<double>()});

	LOG_INFO(topic()) << "hot water " << update.current << " C, "
	                  << update.history.size() << " history point(s)";

	reportHealth(Health::Live);
	if (m_sinks.hotWater)
		m_sinks.hotWater(update);

	waitFor(m_settings.dbIntervalMs);
}
