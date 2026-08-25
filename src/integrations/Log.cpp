#include "Log.hpp"

#include <chrono>
#include <cstdio>
#include <ctime>
#include <iostream>
#include <mutex>

namespace {

std::mutex& sink()
{
	static std::mutex instance;
	return instance;
}

bool parseLevel(const std::string& name, debug::LogLevel* out)
{
	if (name == "debug")   { *out = debug::LogLevel::Debug;   return true; }
	if (name == "info")    { *out = debug::LogLevel::Info;    return true; }
	if (name == "warning") { *out = debug::LogLevel::Warning; return true; }
	if (name == "error")   { *out = debug::LogLevel::Error;   return true; }
	return false;
}

constexpr const char* kTopics[] = {applog::App, applog::Cfg, applog::Db, applog::Rest,
                                   applog::Mqtt, applog::Location, applog::Perf, applog::Gui};

// The constant behind a name, so a topic that was never registered is refused rather than
// silently doing nothing: SetTopicLogLevel takes any string and ignores one it does not know.
const char* topicNamed(const std::string& name)
{
	for (const char* topic : kTopics)
		if (name == topic)
			return topic;
	return nullptr;
}

std::string topicList()
{
	std::string names;
	for (const char* topic : kTopics)
		names += (names.empty() ? "" : ", ") + std::string(topic);
	return names;
}

// Local wall clock to the millisecond. The gap between two lines is what a freeze is read
// from, so the resolution has to be finer than the freeze.
std::string stamp()
{
	const auto now = std::chrono::system_clock::now();
	const auto milliseconds =
		std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
	const std::time_t seconds = std::chrono::system_clock::to_time_t(now);

	std::tm local{};
	localtime_r(&seconds, &local);

	char clock[16];
	std::strftime(clock, sizeof(clock), "%H:%M:%S", &local);

	char text[32];
	std::snprintf(text, sizeof(text), "[%s.%03d] ", clock,
	              static_cast<int>(milliseconds.count()));
	return text;
}

}  // namespace

namespace applog {

void init()
{
	// stdout is a file on the board - the unit redirects it - and a redirected stdout is fully
	// buffered. debug::log writes into cout's streambuf and never flushes it, so without this
	// the log stays empty until 4K has accumulated, and a process that is killed rather than
	// returning from main loses all of it. That is every interesting case: the log is read
	// precisely when the application did not exit cleanly.
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	debug::log::SetOutput(std::cout);

	for (const char* topic : kTopics)
		debug::log::RegisterTopic(topic, debug::LogLevel::Info);
}

void setLevel(const std::string& level)
{
	// One field, or several: a bare level is every topic and `TOPIC=level` is one of them. They
	// are applied in the order they are written, so a bare level after a topic's own wipes it.
	std::size_t at = 0;
	while (at <= level.size()) {
		const std::size_t comma = level.find(',', at);
		const std::string field = (comma == std::string::npos) ? level.substr(at)
		                                                      : level.substr(at, comma - at);
		at = (comma == std::string::npos) ? level.size() + 1 : comma + 1;
		if (field.empty())
			continue;

		const std::size_t equals = field.find('=');
		const std::string name   = (equals == std::string::npos) ? field
		                                                         : field.substr(equals + 1);

		debug::LogLevel minimum = debug::LogLevel::Info;
		if (!parseLevel(name, &minimum)) {
			LOG_ERROR(App) << "unknown log-level '" << name
			               << "' - expected debug, info, warning or error";
			continue;
		}

		if (equals == std::string::npos) {
			for (const char* topic : kTopics)
				debug::log::SetTopicLogLevel(topic, minimum);
			continue;
		}

		const std::string wanted = field.substr(0, equals);
		const char* const topic  = topicNamed(wanted);
		if (topic == nullptr) {
			LOG_ERROR(App) << "unknown log topic '" << wanted << "' - it is one of "
			               << topicList();
			continue;
		}
		debug::log::SetTopicLogLevel(topic, minimum);
	}
}

std::ostream& stream(debug::LogLevel level, const char* topic)
{
	return debug::log::GetStream(level, topic);
}

Line::Line(debug::LogLevel level, const char* topic)
	: m_level(level), m_topic(topic)
{
}

Line::~Line()
{
	const std::lock_guard<std::mutex> guard(sink());
	debug::log::GetStream(m_level, m_topic) << stamp() << m_text.str() << "\n";
}

}  // namespace applog
