#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
	QGuiApplication app(argc, argv);

	QQmlApplicationEngine engine;
	// A QML error is not an exit. loadFromModule() returns void, and an engine that
	// created nothing still enters the event loop and stays there - a live process
	// painting no frames, which on a board is indistinguishable from a dead GPU.
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
	                 &app, [] { QCoreApplication::exit(1); },
	                 Qt::QueuedConnection);
	engine.loadFromModule("QtHmi", "Main");

	return app.exec();
}
