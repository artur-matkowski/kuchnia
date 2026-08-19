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
