#include <iostream>

#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "integrations/Integrations.hpp"
#include "integrations/Log.hpp"
#include "integrations/Settings.hpp"

int main(int argc, char *argv[])
{
	// Logging comes up before the settings, because reading them logs: a missing config
	// file and a default one being written are both said out loud, and neither has anywhere
	// to go until the logger has an output buffer.
	applog::init();

	Settings settings;
	std::string message;
	switch (loadSettings(argc, argv, &settings, &message)) {
	case SettingsResult::HelpRequested:
		std::cout << message << std::endl;
		return 0;
	case SettingsResult::Failed:
		LOG_ERROR(applog::App) << message;
		return 1;
	case SettingsResult::Ok:
		break;
	}
	applog::setLevel(settings.logLevel);

	QGuiApplication app(argc, argv);

	QQmlApplicationEngine engine;
	// A QML error is not an exit. loadFromModule() returns void, and an engine that
	// created nothing still enters the event loop and stays there - a live process
	// painting no frames, which on a board is indistinguishable from a dead GPU.
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
	                 &app, [] { QCoreApplication::exit(1); },
	                 Qt::QueuedConnection);
	engine.loadFromModule("QtHmi", "Main");

	// After the scene, and scoped so that every worker thread is joined before main returns.
	// Nothing in the scene reads any of this yet; the services log, and that is the whole of
	// their output.
	Integrations integrations(settings);

	return app.exec();
}
