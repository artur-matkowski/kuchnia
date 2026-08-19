#include "AppState.hpp"

#include <cstring>

#include <QMetaObject>
#include <QQmlEngine>
#include <QString>

#include "Cameras.hpp"
#include "Gate.hpp"
#include "HotWater.hpp"
#include "Radio.hpp"
#include "Weather.hpp"
#include "integrations/Log.hpp"

namespace {

QStringList toStringList(const std::vector<std::string>& values)
{
	QStringList out;
	out.reserve(static_cast<int>(values.size()));
	for (const std::string& value : values)
		out.append(QString::fromStdString(value));
	return out;
}

}  // namespace

AppState::AppState(const Settings& settings, QObject* parent)
	: QObject(parent)
	, m_cameras(new Cameras(toStringList(settings.cameraUrls), this))
	, m_gate(new Gate(this))
	, m_hotWater(new HotWater(this))
	, m_radio(new Radio(toStringList(settings.radioUrls), toStringList(settings.radioNames), this))
	, m_weather(new Weather(this))
{
	m_gate->setControlEnabled(settings.gateControl);
}

void AppState::registerSingletons()
{
	// qmlRegisterSingletonInstance and not QML_SINGLETON: these objects are built from the
	// settings and wired to the services, neither of which the engine knows how to do. The
	// URI has to match the one in CMakeLists.txt's qt_add_qml_module, and nothing checks that
	// - a mismatch is a runtime "is not a type", not a build failure.
	//
	// The engine takes no ownership; every one of these outlives it because AppState is
	// declared before the engine in main().
	qmlRegisterSingletonInstance("QtHmi", 1, 0, "Cameras", m_cameras);
	qmlRegisterSingletonInstance("QtHmi", 1, 0, "Gate", m_gate);
	qmlRegisterSingletonInstance("QtHmi", 1, 0, "HotWater", m_hotWater);
	qmlRegisterSingletonInstance("QtHmi", 1, 0, "Radio", m_radio);
	qmlRegisterSingletonInstance("QtHmi", 1, 0, "Weather", m_weather);
}

void AppState::setGateCommandSink(std::function<void(const std::string&)> sink)
{
	m_gate->setCommandSink(std::move(sink));
}

Sinks AppState::sinks()
{
	Sinks sinks;

	// Every lambda below runs on a service thread and every one of them only queues. The
	// captured payloads are copied into the invocation, so nothing outlives the call.
	HotWater* hotWater = m_hotWater;
	sinks.hotWater = [hotWater](const HotWaterUpdate& update) {
		QMetaObject::invokeMethod(hotWater, [hotWater, update] { hotWater->update(update); },
		                          Qt::QueuedConnection);
	};

	Weather* weather = m_weather;
	sinks.weather = [weather](const WeatherUpdate& update) {
		QMetaObject::invokeMethod(weather, [weather, update] { weather->update(update); },
		                          Qt::QueuedConnection);
	};

	Gate* gate = m_gate;
	sinks.gateState = [gate](const std::string& state) {
		const QString value = QString::fromStdString(state);
		QMetaObject::invokeMethod(gate, [gate, value] { gate->setState(value); },
		                          Qt::QueuedConnection);
	};

	// One sink for all three services; the topic is what routes it, and it is the same
	// pointer applog uses, so a panel with no topic here is silently never updated. Adding a
	// service means adding it to this switch.
	sinks.health = [this](const char* topic, Health health, const std::string& detail) {
		Panel* panel = nullptr;
		if (std::strcmp(topic, applog::Db) == 0)
			panel = m_hotWater;
		else if (std::strcmp(topic, applog::Rest) == 0)
			panel = m_weather;
		else if (std::strcmp(topic, applog::Mqtt) == 0)
			panel = m_gate;

		if (!panel)
			return;

		const QString text = QString::fromStdString(detail);
		QMetaObject::invokeMethod(panel, [panel, health, text] { panel->setHealth(health, text); },
		                          Qt::QueuedConnection);
	};

	return sinks;
}
