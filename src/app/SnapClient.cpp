#include "SnapClient.hpp"

#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <QUrl>

#include "integrations/Log.hpp"

namespace {

const QString kScheme = QStringLiteral("snapcast");

// The line snapclient logs once the server has answered its hello, and the only one that
// proves a working connection: the socket opens against a server that then drops the client
// just the same.
const QString kLive = QStringLiteral("ServerSettings - ");

// AixLog stamps every line with its severity, and that is the failure test rather than the
// messages: snapclient's are "Error:", "Exception:", "Failed to send hello request" and
// "Time sync request failed:", which have nothing in common to match on.
const QString kError = QStringLiteral("[Error]");
const QString kFatal = QStringLiteral("[Fatal]");

// THE ONE THAT MATTERS. snapclient retries a server that is not there for ever without
// exiting and without saying anything after the first refusal, so nothing but a clock
// distinguishes a slow connect from a server that will never answer.
constexpr int kConnectTimeoutMs = 10000;

}  // namespace

SnapClient::SnapClient(QObject* parent)
	: Panel(parent)
{
	m_connect = new QTimer(this);
	m_connect->setSingleShot(true);
	m_connect->setInterval(kConnectTimeoutMs);
	connect(m_connect, &QTimer::timeout, this, [this] {
		report(Health::Failed, QStringLiteral("no server"));
	});
}

SnapClient::~SnapClient()
{
	// Through stop(), for the disconnect: the child's finished() lands inside the wait, and
	// a report() from there emits statusChanged on a half-destroyed object.
	stop();
}

bool SnapClient::handles(const QString& url) const
{
	return QUrl(url).scheme() == kScheme;
}

void SnapClient::play(const QString& url)
{
	if (m_child && url == m_url)
		return;

	stop();

	const QUrl    parsed = QUrl(url);
	const QString host   = parsed.host();
	const int     port   = parsed.port();
	const QString hostId = parsed.path().mid(1);

	// No defaults for any of the three. A port of 1704 and a hostID off the MAC address are
	// both what snapclient would do on its own, and both produce a room that plays under a
	// name nobody chose - which is indistinguishable from one that was configured.
	if (host.isEmpty() || port < 0 || hostId.isEmpty()) {
		report(Health::Failed,
		       QStringLiteral("expected snapcast://host:port/room, got ") + url);
		return;
	}

	const QStringList args{
		QStringLiteral("-h"), host,
		QStringLiteral("-p"), QString::number(port),
		QStringLiteral("--hostID"), hostId,
		// Explicit, because the default is alsa and this board's device belongs to
		// pipewire-pulse: an ALSA client there is silence or a fight, never an error.
		QStringLiteral("--player"), QStringLiteral("pulse"),
		QStringLiteral("--logsink"), QStringLiteral("stderr"),
	};

	m_child = new QProcess(this);
	m_child->setProcessChannelMode(QProcess::SeparateChannels);

	connect(m_child, &QProcess::readyReadStandardError, this, &SnapClient::onStderr);

	connect(m_child, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
		m_connect->stop();
		report(Health::Failed, m_child->errorString());
	});

	connect(m_child, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
		m_connect->stop();
		// Not retried here: snapclient retries the server itself, so an exit is the child
		// being gone rather than the stream, and starting another would hide it.
		report(Health::Failed,
		       m_lastLine.isEmpty() ? QStringLiteral("snapclient exited (%1)").arg(code)
		                            : m_lastLine);
	});

	m_url = url;
	report(Health::Connecting, QString());
	m_connect->start();

	// The environment is inherited untouched, and that is load-bearing: PULSE_SERVER comes
	// from the unit and is the only reason the child finds this board's shared sound server.
	// See docs/session.md.
	m_child->start(QStringLiteral("snapclient"), args);

	LOG_INFO(applog::App) << "[snapclient] " << host.toStdString() << ":" << port
	                      << " as " << hostId.toStdString();
}

void SnapClient::stop()
{
	m_connect->stop();
	if (!m_child)
		return;

	// Waited for, unlike CameraFeed's audio child: "exactly one snapclient" has to hold
	// across a next/previous that crosses the boundary twice in a row. It costs nothing on a
	// process that has already been killed.
	m_child->disconnect(this);
	m_child->kill();
	m_child->waitForFinished(2000);
	m_child->deleteLater();
	m_child = nullptr;
	m_url.clear();
	m_lastLine.clear();

	LOG_INFO(applog::App) << "[snapclient] stopped";
}

void SnapClient::onStderr()
{
	const QString text = QString::fromUtf8(m_child->readAllStandardError());
	const QStringList lines = text.split('\n', Qt::SkipEmptyParts);
	for (const QString& line : lines)
		note(line.trimmed());
}

void SnapClient::note(const QString& line)
{
	if (line.isEmpty())
		return;

	m_lastLine = line;
	LOG_DEBUG(applog::App) << "[snapclient] " << line.toStdString();

	if (line.contains(kError) || line.contains(kFatal)) {
		m_connect->stop();
		report(Health::Failed, line);
		return;
	}

	// A reconnect logs this again, which is what takes the card back to live on its own
	// after the server has been away.
	if (line.contains(kLive)) {
		m_connect->stop();
		report(Health::Live, QString());
	}
}

void SnapClient::report(Health health, const QString& detail)
{
	const QString wasStatus = status();
	const QString wasDetail = statusDetail();
	Panel::setHealth(health, detail);
	if (status() == wasStatus && statusDetail() == wasDetail)
		return;
	LOG_INFO(applog::App) << "[snapclient] " << status().toStdString()
	                      << (detail.isEmpty() ? "" : " (" + detail.toStdString() + ")");
}
