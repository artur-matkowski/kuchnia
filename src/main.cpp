#include <iostream>

#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QString>

#include "app/AppState.hpp"
#include "integrations/Integrations.hpp"
#include "integrations/Log.hpp"
#include "integrations/Settings.hpp"

namespace {

// Everything Qt says goes to stderr by default, and on the board stderr is not the file
// anybody reads - S99app redirects stdout into /var/log/app.log. A QML binding warning, the
// media backend's complaints and libav's own lines under them are all invisible there
// exactly when the screen is wrong. This puts them in the log, with a timestamp and a topic.
//
// Qt's ffmpeg backend routes libav's av_log into the qt.multimedia.ffmpeg category, and the
// cameras deliver yuvj420p - the deprecated full-range JPEG YUV format - so libswscale warns
// once per scaler context, per camera, per reconnect. It is harmless and it is not
// actionable: nothing here chooses the decoder's output format. Dropping that one line is
// the point of the filter, and the filter is deliberately that narrow - a category-wide
// silence would take real ffmpeg errors with it.
void routeQtMessages(QtMsgType type, const QMessageLogContext&, const QString& message)
{
	if (message.contains(QStringLiteral("deprecated pixel format used")))
		return;

	const std::string text = message.toStdString();
	switch (type) {
	case QtDebugMsg:    LOG_DEBUG(applog::Gui) << text; break;
	case QtInfoMsg:     LOG_INFO(applog::Gui) << text; break;
	case QtWarningMsg:  LOG_WARN(applog::Gui) << text; break;
	case QtCriticalMsg:
	case QtFatalMsg:    LOG_ERROR(applog::Gui) << text; break;
	}
}

// The target ships no fonts and has no fontconfig, so a Text item there draws nothing at all
// and says nothing about it - every label, axis and reading is simply absent. The bundled
// face is what makes the scene independent of the image; the return value is checked because
// the failure it reports is otherwise indistinguishable from a working screen with no text.
void loadBundledFont()
{
	const int id = QFontDatabase::addApplicationFont(":/fonts/LiberationSans-Regular.ttf");
	QFontDatabase::addApplicationFont(":/fonts/LiberationSans-Bold.ttf");

	if (id < 0) {
		LOG_ERROR(applog::App) << "the bundled font did not load - no text will be drawn";
		return;
	}

	const QStringList families = QFontDatabase::applicationFontFamilies(id);
	if (families.isEmpty()) {
		LOG_ERROR(applog::App) << "the bundled font loaded but named no family";
		return;
	}

	QGuiApplication::setFont(QFont(families.first()));
	LOG_INFO(applog::App) << "font: " << families.first().toStdString();
}

}  // namespace

int main(int argc, char *argv[])
{
	// Logging comes up before the settings, because reading them logs: a missing config
	// file and a default one being written are both said out loud, and neither has anywhere
	// to go until the logger has an output buffer.
	applog::init();

	// After init(), because a line written before it is dropped without a word, and before
	// QGuiApplication, which is the first thing that has anything to say.
	qInstallMessageHandler(routeQtMessages);

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

	// QSettings refuses to open a file without these and says so only as a warning, so the
	// radio's remembered station would silently never be written. QML's Settings type is the
	// only thing that reads them.
	QCoreApplication::setOrganizationName("qt-hmi");
	QCoreApplication::setOrganizationDomain("qt-hmi.local");
	QCoreApplication::setApplicationName("qt-hmi");

	loadBundledFont();

	// Declaration order here is destruction order reversed, and both matter. The engine is
	// torn down first, then the service threads are joined, and only then do the objects
	// their callbacks point at go away - so a worker cannot queue onto a destroyed facade.
	AppState state(settings);
	Integrations integrations(settings, state.sinks());
	state.setGateCommandSink([&integrations](const std::string& command) {
		integrations.sendGateCommand(command);
	});

	QQmlApplicationEngine engine;

	// Before the load, or the scene resolves none of these names. Queued calls that arrive
	// in the meantime simply sit in the event queue until exec().
	state.registerSingletons();

	// A QML error is not an exit. loadFromModule() returns void, and an engine that
	// created nothing still enters the event loop and stays there - a live process
	// painting no frames, which on a board is indistinguishable from a dead GPU.
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
	                 &app, [] { QCoreApplication::exit(1); },
	                 Qt::QueuedConnection);
	engine.loadFromModule("QtHmi", "Main");

	return app.exec();
}
