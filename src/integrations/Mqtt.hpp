#pragma once

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "Service.hpp"
#include "Settings.hpp"
#include "Sinks.hpp"

namespace mqtt { class async_client; }

// The broker client: subscribes to the HC-12 bridge's gate topics, holds a retained
// online/offline topic of its own, and optionally sends one gate command.
//
// Reconnection is paho's, not Service's. The library reconnects on its own schedule and
// re-runs the connected handler, which asks this thread to re-establish the subscriptions
// and the retained status - so a broker that comes back heals on its own. Service's backoff
// only covers a connect that never succeeded in the first place.
class Mqtt : public Service {
public:
	Mqtt(const Settings& settings, Sinks sinks);
	~Mqtt() override;

	// The one way into this service from outside, and the only one there may be. Queues the
	// command and wakes the worker; it never publishes on the caller's thread, because
	// publish() waits for the broker's PUBACK and the caller is the thread painting the
	// screen. Safe from any thread.
	void requestGateCommand(const std::string& command);

protected:
	void step() override;
	void reset() override;

private:
	void onConnected();
	void announce();
	void publish(const std::string& topic, const std::string& payload, bool retained);
	void sendGateCommand(const std::string& command);
	void drainCommands();

	const Settings&                     m_settings;
	Sinks                               m_sinks;
	std::unique_ptr<mqtt::async_client> m_client;
	std::atomic<bool>                   m_announce{false};
	std::atomic<bool>                   m_startupCommandSent{false};
	std::mutex                          m_commandMutex;
	std::vector<std::string>            m_commands;
};
