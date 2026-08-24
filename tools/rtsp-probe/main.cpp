// rtsp-probe - the same tiles, the same VideoOutput, two different ways of filling it.
//
// Not part of the application and not in the package: it exists to answer whether a camera
// that will not come up is the stream, the network, or Qt's media backend. Built only with
// -DKUCHNIA_TOOLS=ON. See docs/rtsp.md.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QVariant>

#include <QFile>
#include <QStringList>
#include <QTextStream>

#include <cstdio>

#include "Feed.hpp"

namespace {

void usage()
{
	std::fputs(
		"rtsp-probe - play RTSP streams with Qt's decoder, or with none of it\n"
		"\n"
		"    rtsp-probe --backend ffmpeg --url URL [--url URL...]\n"
		"    rtsp-probe --backend qt --config ./config.conf\n"
		"\n"
		"    --backend ffmpeg|qt   ffmpeg writes raw frames down a pipe and Qt only blits\n"
		"                          them; qt is a MediaPlayer, the application's own path\n"
		"    --url URL             repeatable; overrides --config\n"
		"    --config PATH         take every camera-url from this file\n"
		"    --transport auto|tcp|udp   ffmpeg backend only (default auto)\n"
		"    --fullscreen          take the screen rather than a 1366x768 window\n",
		stderr);
}

// Deliberately not the Config module: a tool that reads one key out of one file does not need
// a spec table, and the file's format is one `key:value` per line.
QStringList camerasFrom(const QString& path)
{
	QFile file(path);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
		std::fputs(qPrintable("error: cannot read " + path + "\n"), stderr);
		return {};
	}
	QTextStream in(&file);
	while (!in.atEnd()) {
		const QString line = in.readLine();
		if (line.startsWith("camera-url:"))
			return line.mid(QStringLiteral("camera-url:").size()).split(',', Qt::SkipEmptyParts);
	}
	return {};
}

// Every URL carries a password and every label ends up in a log. The host is what tells the
// five apart, and it is the only part worth printing.
QString labelFor(const QString& url, int index)
{
	QString rest = url.mid(url.indexOf("://") + 3);
	rest = rest.mid(rest.indexOf('@') + 1);
	const QString host = rest.left(rest.indexOf('/'));
	return QString("%1:%2").arg(index + 1).arg(host.isEmpty() ? url : host);
}

} // namespace

int main(int argc, char* argv[])
{
	QGuiApplication app(argc, argv);

	QString     backend   = "ffmpeg";
	QString     transport = "auto";
	QString     config;
	QStringList urls;
	bool        fullscreen = false;

	const QStringList args = QCoreApplication::arguments();
	for (int i = 1; i < args.size(); ++i) {
		const QString& arg = args.at(i);
		const bool     more = i + 1 < args.size();
		if (arg == "--backend" && more)
			backend = args.at(++i);
		else if (arg == "--url" && more)
			urls << args.at(++i);
		else if (arg == "--config" && more)
			config = args.at(++i);
		else if (arg == "--transport" && more)
			transport = args.at(++i);
		else if (arg == "--fullscreen")
			fullscreen = true;
		else {
			usage();
			return 2;
		}
	}

	if (backend != "ffmpeg" && backend != "qt") {
		std::fputs("error: --backend is ffmpeg or qt\n", stderr);
		return 2;
	}

	if (urls.isEmpty() && !config.isEmpty())
		urls = camerasFrom(config);
	if (urls.isEmpty()) {
		std::fputs("error: no stream to play - give --url or --config\n", stderr);
		usage();
		return 2;
	}

	QVariantList feeds;
	QList<Feed*> owned;
	for (int i = 0; i < urls.size(); ++i) {
		auto* feed = new Feed(urls.at(i).trimmed(), labelFor(urls.at(i), i), transport, &app);
		owned << feed;
		feeds << QVariant::fromValue(static_cast<QObject*>(feed));
	}

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty("feeds", feeds);
	engine.rootContext()->setContextProperty("backend", backend);
	engine.rootContext()->setContextProperty("wantFullscreen", fullscreen);

	QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
	                 [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
	engine.loadFromModule("RtspProbe", "Probe");
	if (engine.rootObjects().isEmpty())
		return 1;

	// After the load and not before it: attaching the sink is the scene's Component.onCompleted,
	// and a feed started ahead of that decodes frames with nowhere to put them - which shows up
	// as a first-frame time that includes however long the window took to build.
	if (backend == "ffmpeg")
		for (Feed* feed : owned)
			feed->start();

	return app.exec();
}
