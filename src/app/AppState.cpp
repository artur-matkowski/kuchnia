#include "AppState.hpp"

#include <cstring>

#include <QMetaObject>
#include <QQmlEngine>
#include <QString>

#include "CameraFeed.hpp"
#include "Cameras.hpp"
#include "Gate.hpp"
#include "HotWater.hpp"
#include "KeyBindings.hpp"
#include "People.hpp"
#include "Radio.hpp"
#include "Trace.hpp"
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
	, m_cameras(new Cameras(toStringList(settings.cameraUrls), settings.cameraHoldMs,
	                        QString::fromStdString(settings.cameraTransport), this))
	, m_gate(new Gate(this))
	, m_hotWater(new HotWater(this))
	, m_keys(new KeyBindings(QString::fromStdString(settings.keyBindings),
	                         settings.keyReset, this))
	, m_people(new People(QString::fromStdString(settings.mapTileUrl), this))
	, m_radio(new Radio(QString::fromStdString(settings.radioM3u), this))
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
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "Cameras", m_cameras);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "Gate", m_gate);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "HotWater", m_hotWater);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "KeyBindings", m_keys);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "People", m_people);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "Radio", m_radio);
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "Weather", m_weather);

	// The one instantiable type, and not a singleton: there is one of these per tile and each
	// owns its own child processes. Registered here anyway, so that every name the scene
	// resolves is registered in one file - see docs/app.md.
	qmlRegisterType<CameraFeed>("Kuchnia", 1, 0, "CameraFeed");

	// Not one of these objects and not built from the settings: a process-level facility that
	// happens to be reached from QML. It is registered here so that every name the scene
	// resolves is registered in one file - see docs/app.md.
	qmlRegisterSingletonInstance("Kuchnia", 1, 0, "Trace", &Trace::instance());
}

void AppState::setGateCommandSink(std::function<void(const std::string&)> sink)
{
	m_gate->setCommandSink(std::move(sink));
}

void AppState::setPeopleRefreshSink(std::function<void()> sink)
{
	m_people->setRefreshSink(std::move(sink));
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

	People* people = m_people;
	sinks.people = [people](const PeopleUpdate& update) {
		QMetaObject::invokeMethod(people, [people, update] { people->update(update); },
		                          Qt::QueuedConnection);
	};

	Gate* gate = m_gate;
	sinks.gateState = [gate](const std::string& state) {
		const QString value = QString::fromStdString(state);
		QMetaObject::invokeMethod(gate, [gate, value] { gate->setState(value); },
		                          Qt::QueuedConnection);
	};

	// One sink for all four services; the topic is what routes it, and it is the same
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
		else if (std::strcmp(topic, applog::Location) == 0)
			panel = m_people;

		if (!panel)
			return;

		const QString text = QString::fromStdString(detail);
		QMetaObject::invokeMethod(panel, [panel, health, text] { panel->setHealth(health, text); },
		                          Qt::QueuedConnection);
	};

	return sinks;
}
