#include "Trace.hpp"

#include <chrono>
#include <iomanip>

#include <QTimer>

#include "integrations/Log.hpp"

namespace {

// The heartbeat's period, and the watchdog's. How long the GUI thread may be silent before it
// is called blocked, and how often a block that goes on says so again - a freeze that lasts
// ten seconds leaves a trail rather than one line at the front of it.
constexpr int kHeartbeatMs = 50;
constexpr int kPollMs      = 50;
constexpr int kStallMs     = 250;
constexpr int kRepeatMs    = 1000;

std::int64_t nowNs()
{
	return std::chrono::duration_cast<std::chrono::nanoseconds>(
		std::chrono::steady_clock::now().time_since_epoch()).count();
}

std::int64_t toMs(std::int64_t nanoseconds)
{
	return nanoseconds / 1000000;
}

}  // namespace

Trace& Trace::instance()
{
	static Trace trace;
	return trace;
}

Trace::Trace(QObject* parent)
	: QObject(parent)
	, m_enabled(debug::log::GetTopicLogLevel(applog::Perf) == debug::LogLevel::Debug)
	, m_alive(nowNs())
{
}

Trace::~Trace()
{
	stop();
}

void Trace::begin(const QString& tag)
{
	const std::int64_t at = nowNs();
	const std::lock_guard<std::mutex> guard(m_mutex);
	m_stack.push_back({tag.toStdString(), at});
}

double Trace::end(const QString& tag)
{
	const std::int64_t at = nowNs();
	const std::string  name = tag.toStdString();

	double      elapsed = 0;
	std::size_t depth   = 0;
	std::string open;
	{
		const std::lock_guard<std::mutex> guard(m_mutex);
		if (m_stack.empty() || m_stack.back().tag != name) {
			open = m_stack.empty() ? "nothing" : m_stack.back().tag;
		} else {
			elapsed = static_cast<double>(at - m_stack.back().startNs) / 1000000.0;
			depth   = m_stack.size();
			m_stack.pop_back();
		}
	}

	if (depth == 0) {
		LOG_ERROR(applog::Perf) << "end('" << name << "') while '" << open
		                        << "' is the open span - the pair is broken and every "
		                        << "duration around it is wrong";
		return 0;
	}

	if (m_enabled)
		LOG_DEBUG(applog::Perf) << "span " << name << " " << std::fixed << std::setprecision(2)
		                        << elapsed << " ms depth=" << depth;

	return elapsed;
}

void Trace::mark(const QString& tag)
{
	if (!m_enabled)
		return;
	LOG_DEBUG(applog::Perf) << "mark " << tag.toStdString();
}

void Trace::watch()
{
	if (m_heartbeat != nullptr)
		return;

	m_alive.store(nowNs());

	// The one thing that says the GUI thread is alive. It is a timer and not a hook in the
	// event loop because a blocked thread is exactly a thread that cannot run either - the
	// silence is the signal.
	m_heartbeat = new QTimer(this);
	m_heartbeat->setInterval(kHeartbeatMs);
	QObject::connect(m_heartbeat, &QTimer::timeout, this, [this] { m_alive.store(nowNs()); });
	m_heartbeat->start();

	m_watchdog = std::thread([this] { poll(); });
}

void Trace::stop()
{
	if (m_watchdog.joinable()) {
		m_stopping.store(true);
		m_watchdog.join();
	}
	delete m_heartbeat;
	m_heartbeat = nullptr;
}

// The watchdog thread. It reports WHILE the GUI thread is blocked, which is the whole reason
// it is not a timer: a timer on that thread can only say how late it was once the thread is
// running again, and a process killed during the freeze leaves nothing at all.
void Trace::poll()
{
	std::int64_t reportedAt = 0;
	std::int64_t blockedMs  = 0;

	while (!m_stopping.load()) {
		std::this_thread::sleep_for(std::chrono::milliseconds(kPollMs));

		const std::int64_t at = nowNs();
		const std::int64_t silentMs = toMs(at - m_alive.load());

		// The heartbeat has run again, so `silentMs` is now the age of a tick and not the
		// length of the block. The last one seen while it was still blocked is that length.
		if (silentMs < kStallMs) {
			if (reportedAt != 0) {
				LOG_WARN(applog::Perf) << "the gui thread is answering again, after "
				                       << blockedMs << " ms";
				reportedAt = 0;
			}
			blockedMs = 0;
			continue;
		}

		blockedMs = silentMs;

		if (reportedAt != 0 && toMs(at - reportedAt) < kRepeatMs)
			continue;
		reportedAt = at;

		std::string  tag;
		std::int64_t openMs = 0;
		{
			const std::lock_guard<std::mutex> guard(m_mutex);
			if (!m_stack.empty()) {
				tag    = m_stack.back().tag;
				openMs = toMs(at - m_stack.back().startNs);
			}
		}

		if (!tag.empty())
			LOG_WARN(applog::Perf) << "the gui thread has been blocked for " << silentMs
			                       << " ms, inside '" << tag << "' (open " << openMs << " ms)";
		else
			LOG_WARN(applog::Perf) << "the gui thread has been blocked for " << silentMs
			                       << " ms, with no span open - the block is outside the "
			                       << "instrumented path: render sync, event delivery, or C++ "
			                       << "under a binding";
	}

	// The recovery line above is the one that names the length of a block, so a run that ends
	// inside one has to say so here or the last freeze is the one nobody can measure.
	if (blockedMs >= kStallMs)
		LOG_WARN(applog::Perf) << "the run ended with the gui thread blocked for " << blockedMs
		                       << " ms";
}
