#pragma once

#include <sstream>
#include <string>

#include "Logger.hpp"

// Logger.hpp defines ERROR, WARNING, INFO and ALL as object-like macros, to drive its own
// MAX_LOG_LEVEL comparisons. Nothing downstream of this header sees them: an enumerator or
// a member named ERROR anywhere else fails to parse, and the error names that line rather
// than the logger that broke it.
#undef ERROR
#undef WARNING
#undef INFO
#undef ALL

namespace applog {

// Every topic used anywhere in the program. debug::log prints a complaint to cerr for each
// line written under a topic it was never told about, so all of them are registered by
// init() whether or not the module that owns one is enabled.
inline constexpr const char* App  = "APP";
inline constexpr const char* Cfg  = "CONFIG";
inline constexpr const char* Db   = "DB";
inline constexpr const char* Rest = "REST";
inline constexpr const char* Mqtt = "MQTT";

// Where the GUI thread was when it stopped answering - see docs/diagnostics.md. Silent at
// info: the spans are debug lines and only the watchdog's stall reports are warnings.
inline constexpr const char* Perf = "PERF";

// Everything Qt itself says - the scene graph, QML warnings, the media backend and libav
// under it. main.cpp installs the handler that routes them here; without it they go to
// stderr, which on the board is not the file anybody reads.
inline constexpr const char* Gui  = "QT";

// Points the logger at stdout and registers every topic. Until this runs the logger holds a
// null output buffer and drops every line written through it, reporting nothing at all - not
// even to say that a logger exists.
//
// Called before the settings are read, because reading them logs; setLevel() then applies
// what they turned out to say.
void init();

// The minimum level, either for every topic - "info" - or for every topic and then some of
// them by name: "info,QT=debug,PERF=debug". Fields are applied LEFT TO RIGHT, so a bare level
// after a topic's own wipes it. An unrecognised level or topic is reported and changes
// nothing.
void setLevel(const std::string& level);

// The logger's own stream for one level, for handing to a library that logs into a
// std::ostream. Each '\n' written to it becomes one prefixed line.
//
// It bypasses Line and therefore the lock: a library given these must be one that logs from
// a single thread. Module-cpp-config qualifies - it is finished before any worker starts.
std::ostream& stream(debug::LogLevel level, const char* topic);

// One log line, assembled off to the side and emitted whole in the destructor.
//
// debug::log hands out one shared std::ostream per (level, topic) and flushes it only on
// '\n'. Writing through it directly makes a forgotten newline into a line that never
// appears, and two threads on one topic into interleaved bytes - both silent. Going
// through this type makes each line atomic and terminated by construction.
//
// It is also what puts a wall clock time on the line. The logger writes none, and a log with
// no times in it cannot answer the only question a freeze asks: how long was the gap.
class Line {
public:
	Line(debug::LogLevel level, const char* topic);
	~Line();

	Line(const Line&) = delete;
	Line& operator=(const Line&) = delete;

	template <typename T>
	Line& operator<<(const T& value) { m_text << value; return *this; }

private:
	std::ostringstream m_text;
	debug::LogLevel    m_level;
	const char*        m_topic;
};

}  // namespace applog

#define LOG_ERROR(topic) applog::Line(debug::LogLevel::Error, topic)
#define LOG_WARN(topic)  applog::Line(debug::LogLevel::Warning, topic)
#define LOG_INFO(topic)  applog::Line(debug::LogLevel::Info, topic)
#define LOG_DEBUG(topic) applog::Line(debug::LogLevel::Debug, topic)
