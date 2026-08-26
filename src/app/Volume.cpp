#include "Volume.hpp"

#include <QProcess>

#include "integrations/Log.hpp"

namespace {

// The server resolves this at the moment of the call, so the keys move whichever sink is
// default then - and PULSE_SERVER points pactl at the same daemon as the rest of the process,
// which is what makes it the sink the radio and the cameras are heard through. See
// docs/volume.md.
const char* const kSink = "@DEFAULT_SINK@";

const char* const kStep = "5%";

}  // namespace

void Volume::up()
{
	step(QStringLiteral("+") + QLatin1String(kStep));
}

void Volume::down()
{
	step(QStringLiteral("-") + QLatin1String(kStep));
}

void Volume::step(const QString& delta)
{
	QProcess* pactl = new QProcess(this);

	connect(pactl, &QProcess::errorOccurred, this, [pactl](QProcess::ProcessError) {
		// Almost always "no such program": pulseaudio-utils is a package dependency that
		// dh_shlibdeps cannot see - docs/packaging.md. No finished() follows this one.
		LOG_ERROR(applog::App) << "volume: " << pactl->errorString().toStdString();
		pactl->deleteLater();
	});

	connect(pactl, &QProcess::finished, this, [pactl](int code, QProcess::ExitStatus) {
		if (code != 0)
			LOG_ERROR(applog::App) << "volume: pactl exited " << code << ": "
			                       << pactl->readAllStandardError().trimmed().toStdString();
		pactl->deleteLater();
	});

	pactl->start(QStringLiteral("pactl"),
	             {QStringLiteral("set-sink-volume"), QLatin1String(kSink), delta});
}
