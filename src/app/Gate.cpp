#include "Gate.hpp"

#include "integrations/Log.hpp"

void Gate::setCommandSink(std::function<void(const std::string&)> sink)
{
	m_command = std::move(sink);
}

void Gate::setState(const QString& state)
{
	if (state == m_state)
		return;
	m_state = state;
	emit stateChanged();
}

// The signal names are the HC-12 bridge's own; the subscription list in Settings.cpp carries
// the same set, and a signal added there needs adding here or its state enables all three
// commands.
bool Gate::canOpen() const
{
	return m_controlEnabled && m_state != "GateOpened" && m_state != "GateOpening";
}

bool Gate::canClose() const
{
	return m_controlEnabled && m_state != "GateClosed" && m_state != "GateClosing";
}

// Denied only by the three states in which nothing is moving, so a stuck gate - which is
// still driving its motor - can always be stopped.
bool Gate::canStop() const
{
	return m_controlEnabled && m_state != "GateOpened" && m_state != "GateClosed"
	    && m_state != "GateStopped";
}

// stop() would shadow nothing here, but the QML side reads better as halt() next to open()
// and close(), and the bridge's own name for it is StopGate either way.
void Gate::open()  { send("OpenGate"); }
void Gate::close() { send("CloseGate"); }
void Gate::halt()  { send("StopGate"); }

void Gate::send(const char* command)
{
	if (!m_command) {
		LOG_ERROR(applog::App) << "gate command '" << command << "' dropped: no broker";
		return;
	}
	// Only queues. The publish happens on the broker client's thread, because it waits for a
	// PUBACK and this is the thread painting the screen.
	m_command(command);
}
