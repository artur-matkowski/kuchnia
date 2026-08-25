#pragma once

#include <functional>
#include <string>

#include <QObject>

#include "integrations/Settings.hpp"
#include "integrations/Sinks.hpp"

class Cameras;
class Gate;
class HotWater;
class KeyBindings;
class People;
class Radio;
class Weather;

// Owns everything the scene binds to, and is the only place a worker thread's data becomes a
// Qt property.
//
// THE INVARIANT: the callbacks sinks() hands out are called on service threads, and every
// one of them does nothing but QMetaObject::invokeMethod(..., Qt::QueuedConnection) onto
// this object. Nothing else in src/app/ is ever touched from another thread. Setting a
// Q_PROPERTY from a worker thread does not crash and does not warn - it corrupts a binding
// somewhere else, minutes later, and that is what this arrangement exists to prevent.
//
// Construct on the GUI thread, before Integrations, and register before the engine loads.
class AppState : public QObject {
	Q_OBJECT

public:
	explicit AppState(const Settings& settings, QObject* parent = nullptr);

	// Must run before QQmlApplicationEngine::loadFromModule: a singleton registered after the
	// scene is built is a name QML has already failed to resolve.
	void registerSingletons();

	// Callable from any thread, for the lifetime of this object. Integrations is constructed
	// after this and destroyed before it, which is what makes that true.
	Sinks sinks();

	// Where the gate buttons publish to, and where the map's refresh key wakes the roster's
	// poll. Both set after Integrations exists, since that is what owns the services.
	void setGateCommandSink(std::function<void(const std::string&)> sink);
	void setPeopleRefreshSink(std::function<void()> sink);

private:
	Cameras*     m_cameras;
	Gate*        m_gate;
	HotWater*    m_hotWater;
	KeyBindings* m_keys;
	People*      m_people;
	Radio*       m_radio;
	Weather*     m_weather;
};
