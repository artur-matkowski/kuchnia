#pragma once

#include <atomic>
#include <memory>
#include <string>

#include "Service.hpp"
#include "Settings.hpp"

namespace mqtt { class async_client; }

// The broker client: subscribes to the HC-12 bridge's gate topics, holds a retained
// online/offline topic of its own, and optionally sends one gate command.
//
// Reconnection is paho's, not Service's. The library reconnects on its own schedule and
// re-runs the connected handler, which is where the subscriptions and the retained status
// are re-established - so a broker that comes back heals without this thread doing anything.
// Service's backoff only covers a connect that never succeeded in the first place.
class Mqtt : public Service {
public:
	explicit Mqtt(const Settings& settings);
	~Mqtt() override;

protected:
	void step() override;
	void reset() override;

private:
	void onConnected();
	void publish(const std::string& topic, const std::string& payload, bool retained);
	void sendGateCommand();

	const Settings&                     m_settings;
	std::unique_ptr<mqtt::async_client> m_client;
	std::atomic<bool>                   m_gateCommandSent{false};
};
