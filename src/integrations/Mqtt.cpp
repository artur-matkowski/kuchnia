#include "Mqtt.hpp"

#include <algorithm>
#include <chrono>
#include <stdexcept>

#include <mqtt/async_client.h>

#include "Log.hpp"

namespace {

constexpr int kQos = 1;

// The gate commands the HC-12 bridge accepts. Anything else published under hc12/tx is
// rejected by the bridge, so refusing it here keeps the rejection next to the typo.
bool isGateCommand(const std::string& name)
{
	return name == "OpenGate" || name == "CloseGate" || name == "StopGate";
}

// paho reports every CONNACK rejection as MQTTAsync_strerror's "CONNACK return code", which
// names neither the code nor the identity the broker judged. rc is the MQTT 3.1.1 CONNACK
// byte; paho's own failures are negative and keep their own text.
const char* connackReason(int rc)
{
	switch (rc) {
	case 1:  return "unacceptable protocol version";
	case 2:  return "identifier rejected";
	case 3:  return "server unavailable";
	case 4:  return "bad user name or password";
	case 5:  return "not authorized";
	default: return nullptr;
	}
}

}  // namespace

Mqtt::Mqtt(const Settings& settings)
	: Service(applog::Mqtt, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
{
}

Mqtt::~Mqtt()
{
	stop();

	if (!m_client)
		return;
	try {
		// The last will covers a process that dies; a process that is asked to stop says so
		// itself, otherwise the topic reads online until the broker's keepalive expires.
		publish(m_settings.mqttStatusTopic, "offline", true);
		m_client->disconnect()->wait();
	} catch (const std::exception& error) {
		LOG_WARN(topic()) << "disconnect: " << error.what();
	}
}

void Mqtt::reset()
{
	m_client.reset();
}

void Mqtt::publish(const std::string& topicName, const std::string& payload, bool retained)
{
	m_client->publish(mqtt::make_message(topicName, payload, kQos, retained))->wait();
}

void Mqtt::sendGateCommand()
{
	if (m_settings.gateCommand.empty())
		return;

	if (!m_settings.gateControl) {
		LOG_ERROR(topic()) << "gate-command '" << m_settings.gateCommand
		                   << "' ignored: gate-control is not set";
		return;
	}
	if (!isGateCommand(m_settings.gateCommand)) {
		LOG_ERROR(topic()) << "gate-command '" << m_settings.gateCommand
		                   << "' is not OpenGate, CloseGate or StopGate";
		return;
	}
	if (m_gateCommandSent.exchange(true))
		return;

	// Never retained. The broker persists retained messages, so a retained hc12/tx/OpenGate
	// is replayed to the bridge on every one of its restarts - the gate would then open by
	// itself, forever, until somebody cleared the topic by hand.
	const std::string commandTopic = "hc12/tx/" + m_settings.gateCommand;
	const std::string payload = "{\"idTarget\":" + std::to_string(m_settings.gateTarget) + "}";
	publish(commandTopic, payload, false);

	LOG_WARN(topic()) << "published " << commandTopic << " " << payload;
}

void Mqtt::onConnected()
{
	// Runs on paho's callback thread, on the first connect and on every automatic reconnect
	// after it - which is what makes the subscriptions and the retained status survive a
	// broker restart without this class tracking one.
	//
	// This thread is also the one that delivers SUBACK and PUBACK, so a token wait()ed on
	// here can never be completed: subscribing from this function deadlocks the client
	// silently and for good, with no error and no traffic. All it may do is ask the service
	// thread to do the work, where waiting is safe and a failure can still be thrown.
	m_announce.store(true);
	wake();
}

void Mqtt::announce()
{
	for (const std::string& subscription : m_settings.mqttSubscribe)
		m_client->subscribe(subscription, kQos)->wait();

	LOG_INFO(topic()) << "connected, " << m_settings.mqttSubscribe.size() << " subscription(s)";

	publish(m_settings.mqttStatusTopic, "online", true);
	sendGateCommand();
}

void Mqtt::step()
{
	if (!m_client) {
		const std::string uri = "tcp://" + m_settings.mqttHost + ":" +
		                        std::to_string(m_settings.mqttPort);

		m_client = std::make_unique<mqtt::async_client>(uri, m_settings.mqttClientId);

		m_client->set_connected_handler([this](const std::string&) { onConnected(); });
		m_client->set_connection_lost_handler([this](const std::string& cause) {
			LOG_WARN(topic()) << "connection lost"
			                  << (cause.empty() ? std::string() : ": " + cause);
		});
		m_client->set_message_callback([this](mqtt::const_message_ptr message) {
			LOG_INFO(topic()) << message->get_topic() << " " << message->to_string();
		});

		const auto options = mqtt::connect_options_builder()
			.user_name(m_settings.mqttUser)
			.password(m_settings.mqttPassword)
			.keep_alive_interval(std::chrono::seconds(60))
			// Nothing here wants messages queued while it was away: every gate topic is
			// retained, so the current state arrives on subscribe regardless.
			.clean_session(true)
			.automatic_reconnect(std::chrono::seconds(1), std::chrono::seconds(30))
			.will(mqtt::message(m_settings.mqttStatusTopic, "offline", kQos, true))
			.finalize();

		try {
			m_client->connect(options)->wait();
		} catch (const mqtt::exception& error) {
			const char* reason = connackReason(error.get_return_code());
			if (!reason)
				throw;
			// The broker weighed these four and refused; a rejection that does not name them
			// reads as a network fault and is debugged as one.
			throw std::runtime_error(
				std::string("connect refused: ") + reason + " - user '" + m_settings.mqttUser +
				"', client-id '" + m_settings.mqttClientId + "', " +
				(m_settings.mqttPassword.empty() ? "no password" : "password set") +
				", will '" + m_settings.mqttStatusTopic + "'");
		}
	}

	if (m_announce.exchange(false))
		announce();

	if (m_settings.mqttHeartbeatMs <= 0) {
		waitFor(std::max(1000, m_settings.retryMaxMs));
		return;
	}

	waitFor(m_settings.mqttHeartbeatMs);
	if (!stopping() && m_client->is_connected())
		publish(m_settings.mqttStatusTopic, "online", true);
}
