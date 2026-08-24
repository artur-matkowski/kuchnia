#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <QObject>
#include <QString>

class QTimer;

// Where the GUI thread was when it stopped answering. See docs/diagnostics.md.
//
// A QML singleton, registered in AppState.cpp with the rest. The span stack is kept whatever
// the log level says, because the watchdog's whole value is naming the span that was open
// while the thread was blocked; only the per-span lines are gated on `enabled`.
class Trace : public QObject {
	Q_OBJECT

	// CONSTANT, and it must stay that way: the chart functions read this inside bindings, and a
	// NOTIFYable property read during an evaluation becomes a dependency of it.
	Q_PROPERTY(bool enabled READ enabled CONSTANT)

public:
	// Built on the first call, which is main()'s - by then the settings have been read and the
	// PERF topic's level is final. Read `enabled` before that and it answers for a level that
	// was never applied.
	static Trace& instance();

	bool enabled() const { return m_enabled; }

	// Tags pair by their exact string. An `end` whose tag is not the open one is reported and
	// nothing is popped: guessing there silently corrupts every duration above it.
	Q_INVOKABLE void begin(const QString& tag);
	Q_INVOKABLE double end(const QString& tag);
	Q_INVOKABLE void mark(const QString& tag);

	// Starts the heartbeat and the watchdog thread. On the GUI thread, after QGuiApplication -
	// the heartbeat is a QTimer and needs an event dispatcher to have somewhere to fire.
	void watch();
	void stop();

private:
	explicit Trace(QObject* parent = nullptr);
	~Trace() override;

	struct Span {
		std::string   tag;
		std::int64_t  startNs;
	};

	void poll();

	const bool m_enabled;

	// Held by both threads. Never taken across a log write: applog has a lock of its own.
	std::mutex        m_mutex;
	std::vector<Span> m_stack;

	std::atomic<std::int64_t> m_alive;
	std::atomic<bool>         m_stopping{false};
	std::thread               m_watchdog;
	QTimer*                   m_heartbeat = nullptr;
};
