#include "Service.hpp"

#include <algorithm>
#include <chrono>
#include <exception>
#include <string>

#include "Log.hpp"

namespace {

// libpq ends every message with a newline, and Poco keeps whatever the peer sent. A log
// line is terminated by its own writer, so an embedded newline splits one report into two -
// the second of which carries no message, only the backoff.
std::string trimmed(const char* text)
{
	std::string out(text ? text : "");
	while (!out.empty() && (out.back() == '\n' || out.back() == '\r' || out.back() == ' '))
		out.pop_back();
	return out;
}

}  // namespace

Service::Service(const char* topic, int retryMinMs, int retryMaxMs)
	: m_topic(topic)
	, m_retryMinMs(std::max(1, retryMinMs))
	, m_retryMaxMs(std::max(std::max(1, retryMinMs), retryMaxMs))
{
}

Service::~Service()
{
	stop();
}

void Service::setHealthSink(std::function<void(const char*, Health, const std::string&)> sink)
{
	m_health = std::move(sink);
}

void Service::reportHealth(Health health, const std::string& detail)
{
	if (m_health)
		m_health(m_topic, health, detail);
}

void Service::start()
{
	if (m_thread.joinable())
		return;
	m_thread = std::thread([this] { run(); });
}

void Service::stop()
{
	{
		const std::lock_guard<std::mutex> guard(m_mutex);
		m_stopping = true;
	}
	m_wakeup.notify_all();
	if (m_thread.joinable())
		m_thread.join();
}

bool Service::stopping()
{
	const std::lock_guard<std::mutex> guard(m_mutex);
	return m_stopping;
}

bool Service::waitFor(int milliseconds)
{
	std::unique_lock<std::mutex> guard(m_mutex);
	m_wakeup.wait_for(guard, std::chrono::milliseconds(milliseconds),
	                  [this] { return m_stopping || m_woken; });
	m_woken = false;
	return !m_stopping;
}

void Service::wake()
{
	{
		const std::lock_guard<std::mutex> guard(m_mutex);
		m_woken = true;
	}
	m_wakeup.notify_all();
}

void Service::run()
{
	int backoff = m_retryMinMs;

	while (!stopping()) {
		try {
			step();
			backoff = m_retryMinMs;
			continue;
		} catch (const std::exception& error) {
			const std::string reason = trimmed(error.what());
			LOG_ERROR(m_topic) << reason << " - retrying in " << backoff << " ms";
			reportHealth(Health::Failed, reason);
		} catch (...) {
			LOG_ERROR(m_topic) << "unknown failure - retrying in " << backoff << " ms";
			reportHealth(Health::Failed, "unknown failure");
		}

		reset();
		if (!waitFor(backoff))
			return;
		backoff = std::min(backoff * 2, m_retryMaxMs);
	}
}
