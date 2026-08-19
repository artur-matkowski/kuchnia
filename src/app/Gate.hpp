#pragma once

#include <functional>
#include <string>

#include <QString>

#include "Panel.hpp"

// The gate: the last signal the HC-12 bridge published, and the three buttons.
//
// state is the bare signal name - GateOpened, GateClosing and so on - and is empty until one
// arrives. It arrives promptly on a healthy broker because every gate topic is retained, so
// an empty state after a "live" status means the bridge has never published, not that the
// connection is slow.
class Gate : public Panel {
	Q_OBJECT
	Q_PROPERTY(QString state READ state NOTIFY stateChanged)
	Q_PROPERTY(bool controlEnabled READ controlEnabled CONSTANT)

public:
	using Panel::Panel;

	QString state() const { return m_state; }

	// Mirrors gate-control. The buttons are shown disabled rather than hidden: a control that
	// is not there cannot be told apart from one that was never built.
	bool controlEnabled() const { return m_controlEnabled; }
	void setControlEnabled(bool enabled) { m_controlEnabled = enabled; }

	// Hands commands to the broker client. Set once, before the scene loads.
	void setCommandSink(std::function<void(const std::string&)> sink);

	// GUI thread only.
	void setState(const QString& state);

	// These publish to hc12/tx and physically move a gate. The names are the bridge's own
	// and are validated again on the service thread before anything leaves the process.
	Q_INVOKABLE void open();
	Q_INVOKABLE void close();
	Q_INVOKABLE void halt();

signals:
	void stateChanged();

private:
	void send(const char* command);

	QString                                 m_state;
	bool                                    m_controlEnabled = false;
	std::function<void(const std::string&)> m_command;
};
