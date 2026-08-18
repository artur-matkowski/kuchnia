#include "Log.hpp"

#include <cstdio>
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

constexpr const char* kTopics[] = {applog::App, applog::Cfg, applog::Db,
                                   applog::Rest, applog::Mqtt};

}  // namespace

namespace applog {

void init()
{
	// stdout is a file on the board - S99app redirects it into /var/log/app.log - and a
	// redirected stdout is fully buffered. debug::log writes into cout's streambuf and
	// never flushes it, so without this the log stays empty until 4K has accumulated, and
	// a process that is killed rather than returning from main loses all of it. That is
	// every interesting case: the log is read precisely when the application did not exit
	// cleanly.
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	debug::log::SetOutput(std::cout);

	for (const char* topic : kTopics)
		debug::log::RegisterTopic(topic, debug::LogLevel::Info);
}

void setLevel(const std::string& level)
{
	debug::LogLevel minimum = debug::LogLevel::Info;
	if (!parseLevel(level, &minimum)) {
		LOG_ERROR(App) << "unknown log-level '" << level
		               << "' - expected debug, info, warning or error";
		return;
	}

	for (const char* topic : kTopics)
		debug::log::SetTopicLogLevel(topic, minimum);
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
	debug::log::GetStream(m_level, m_topic) << m_text.str() << "\n";
}

}  // namespace applog
