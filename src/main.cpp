#include <cstdarg>
#include <cstring>
#include <iostream>
#include <string>

#include <dlfcn.h>
#include <link.h>

#include <QFontDatabase>
#include <QGuiApplication>
#include <QMediaPlayer>
#include <QQmlApplicationEngine>
#include <QString>

#include "app/AppState.hpp"
#include "integrations/Integrations.hpp"
#include "integrations/Log.hpp"
#include "integrations/Settings.hpp"

namespace {

// Everything Qt says goes to stderr by default, and on the board stderr is not the file
// anybody reads - S99app redirects stdout into /var/log/app.log. A QML binding warning and
// the media backend's complaints are both invisible there exactly when the screen is wrong.
// This puts them in the log, with a timestamp and a topic.
void routeQtMessages(QtMsgType type, const QMessageLogContext&, const QString& message)
{
	const std::string text = message.toStdString();
	switch (type) {
	case QtDebugMsg:    LOG_DEBUG(applog::Gui) << text; break;
	case QtInfoMsg:     LOG_INFO(applog::Gui) << text; break;
	case QtWarningMsg:  LOG_WARN(applog::Gui) << text; break;
	case QtCriticalMsg:
	case QtFatalMsg:    LOG_ERROR(applog::Gui) << text; break;
	}
}

// libav's lines do not come through the handler above and cannot be filtered there, so the
// application takes av_log itself. Why, and why one line is dropped, is in docs/app.md.
//
// The levels and the signatures are libav's, written out because there is no build
// dependency on ffmpeg here - the backend is a plugin, and these are looked up in whatever
// the plugin dragged in. Both have been ABI for the lifetime of the library.
constexpr int kAvLogError   = 16;
constexpr int kAvLogWarning = 24;
constexpr int kAvLogInfo    = 32;

using AvLogCallback    = void (*)(void*, int, const char*, va_list);
using AvLogGetLevel    = int (*)();
using AvLogFormatLine  = int (*)(void*, int, const char*, va_list, char*, int, int*);
using AvLogSetCallback = void (*)(AvLogCallback);

AvLogGetLevel   avLogGetLevel   = nullptr;
AvLogFormatLine avLogFormatLine = nullptr;

// Called on libav's decode threads. applog::Line is what makes that safe: it assembles the
// line off to the side and emits it whole, under the lock.
void routeLibavMessages(void* avcl, int level, const char* fmt, va_list args)
{
	// av_vlog does not filter - the level check lives in the default callback, which is
	// exactly what this replaced. Without it every decoder debug line, one per NAL, is
	// formatted here before applog throws it away.
	if (level > avLogGetLevel())
		return;

	char line[1024];
	int prefix = 1;
	avLogFormatLine(avcl, level, fmt, args, line, sizeof(line), &prefix);

	if (std::strstr(line, "deprecated pixel format used") != nullptr)
		return;

	std::string text(line);
	while (!text.empty() && (text.back() == '\n' || text.back() == '\r'))
		text.pop_back();
	if (text.empty())
		return;

	if (level <= kAvLogError)        LOG_ERROR(applog::Gui) << text;
	else if (level <= kAvLogWarning) LOG_WARN(applog::Gui) << text;
	else if (level <= kAvLogInfo)    LOG_INFO(applog::Gui) << text;
	else                             LOG_DEBUG(applog::Gui) << text;
}

// libavutil comes in as a dependency of the media plugin, and Qt dlopens plugins into a
// local scope: RTLD_DEFAULT cannot see a symbol of theirs, and looking one up there answers
// null on a process that plainly has ffmpeg in it. The link map does carry the object, under
// a full path that dlopen resolves back to the copy already in memory.
void* libavutil()
{
	std::string path;
	dl_iterate_phdr(
		[](struct dl_phdr_info* info, size_t, void* found) {
			if (info->dlpi_name == nullptr ||
			    std::strstr(info->dlpi_name, "/libavutil.so") == nullptr)
				return 0;
			*static_cast<std::string*>(found) = info->dlpi_name;
			return 1;
		},
		&path);

	return path.empty() ? nullptr : dlopen(path.c_str(), RTLD_LAZY | RTLD_NOLOAD);
}

void routeLibavLog()
{
	// Constructing a player is what loads the media backend, and the backend is what both
	// brings libavutil into the process and installs the callback this one has to replace.
	// Before this line there is no object to find and nothing to take over from.
	QMediaPlayer backend;

	void* const av = libavutil();
	if (av == nullptr) {
		LOG_INFO(applog::App) << "no libav in the process - its log is left where it is";
		return;
	}

	avLogGetLevel   = reinterpret_cast<AvLogGetLevel>(dlsym(av, "av_log_get_level"));
	avLogFormatLine = reinterpret_cast<AvLogFormatLine>(dlsym(av, "av_log_format_line2"));
	const auto set  = reinterpret_cast<AvLogSetCallback>(dlsym(av, "av_log_set_callback"));

	if (avLogGetLevel == nullptr || avLogFormatLine == nullptr || set == nullptr) {
		LOG_ERROR(applog::App) << "libav is loaded but its log entry points are not - "
		                       << "its output stays on stderr";
		return;
	}

	set(routeLibavMessages);
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

	// Needs the application object for the plugin paths to resolve, and goes in here so that
	// nothing has decoded a frame yet by the time libav's log has somewhere to go.
	routeLibavLog();

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
