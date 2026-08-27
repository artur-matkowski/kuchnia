#include "CameraFeed.hpp"

#include <cstring>

#include <QAudioFormat>
#include <QAudioSink>
#include <QMediaDevices>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QVideoSink>

#include "integrations/Log.hpp"

namespace {

// How long a stream that has delivered a frame may go without another, and how long a fresh
// one gets to produce its first. Connecting and stalling fail on different timescales: a
// camera answers in two to three seconds and the budget has to clear that with room.
constexpr int kStallTimeoutMs   = 5000;
constexpr int kConnectTimeoutMs = 20000;

constexpr int kMinimumRetryMs = 1000;
constexpr int kMaximumRetryMs = 30000;

// What the audio pipe carries, and what the sink is opened for. ffmpeg is told to resample to
// exactly this, so the two cannot disagree.
constexpr int kAudioRate     = 48000;
constexpr int kAudioChannels = 2;

}  // namespace

CameraFeed::CameraFeed(QObject* parent)
	: QObject(parent)
{
	m_retry = new QTimer(this);
	m_retry->setSingleShot(true);
	connect(m_retry, &QTimer::timeout, this, &CameraFeed::spawnVideo);

	m_watchdog = new QTimer(this);
	m_watchdog->setInterval(1000);
	connect(m_watchdog, &QTimer::timeout, this, [this] {
		// A pending retry owns the tile. Without this the stall is reported again on every
		// tick and the backoff climbs while the reconnect it is waiting for never happens.
		if (!m_wanted || m_retry->isActive())
			return;
		const int budget = m_frames == 0 ? kConnectTimeoutMs : kStallTimeoutMs;
		if (m_lastFrame.elapsed() < budget)
			return;
		// THE ONE THAT MATTERS. A camera switched off mid-stream does not close its session
		// and does not error: ffmpeg simply stops being fed and the tile paints its last
		// frame under a green badge for as long as the process runs.
		setHealth(QStringLiteral("failed"),
		          m_frames == 0 ? QStringLiteral("no first frame") : QStringLiteral("stalled"));
		retryLater();
	});
}

CameraFeed::~CameraFeed()
{
	m_wanted = false;
	killAudio();
	if (m_video && m_video->state() != QProcess::NotRunning) {
		m_video->kill();
		m_video->waitForFinished(2000);
	}
}

void CameraFeed::setUrl(const QString& url)
{
	if (m_url == url)
		return;
	m_url = url;
	emit configChanged();
	// A url arriving after start() is the ordinary case inside a Repeater-free screen: the
	// binding is evaluated during creation and start() runs after it. One that CHANGES while
	// running is a different camera, and the child playing the old one has to go.
	if (m_wanted) {
		stop(QStringLiteral("url changed"));
		start();
	}
}

void CameraFeed::setLabel(const QString& label)
{
	if (m_label == label)
		return;
	m_label = label;
	emit configChanged();
}

void CameraFeed::setTransport(const QString& transport)
{
	if (m_transport == transport)
		return;
	m_transport = transport;
	emit configChanged();
}

void CameraFeed::setAudible(bool audible)
{
	if (m_audible == audible)
		return;
	m_audible = audible;
	emit audibleChanged();

	if (m_audible && m_wanted)
		spawnAudio();
	else
		killAudio();
}

void CameraFeed::attach(QVideoSink* sink)
{
	m_video_sink = sink;
	// The only place frames are counted. Wiring this in QML instead is accepted and then
	// silently never fires wherever the Connections lands outside the sink's scope.
	connect(sink, &QVideoSink::videoFrameChanged, this, &CameraFeed::noteFrame);
}

void CameraFeed::setHealth(const QString& health, const QString& detail)
{
	if (health == QStringLiteral("live"))
		m_retryMs = kMinimumRetryMs;
	if (m_health == health && m_detail == detail)
		return;
	m_health = health;
	m_detail = detail;
	LOG_INFO(applog::App) << "[camera] " << m_label.toStdString() << ": " << health.toStdString()
	                      << (detail.isEmpty() ? "" : " (" + detail.toStdString() + ")");
	emit changed();
}

void CameraFeed::start()
{
	if (m_url.isEmpty() || m_wanted)
		return;
	m_wanted = true;
	m_retryMs = kMinimumRetryMs;
	spawnVideo();
	if (m_audible)
		spawnAudio();
}

void CameraFeed::stop(const QString& why)
{
	m_wanted = false;
	m_retry->stop();
	m_watchdog->stop();
	killAudio();
	if (m_video) {
		m_video->disconnect(this);
		m_video->kill();
		m_video->deleteLater();
		m_video = nullptr;
	}
	m_pending.clear();
	m_frameBytes = 0;
	m_frames = 0;
	m_reportedFirst = false;
	setHealth(QStringLiteral("connecting"), why);
}

void CameraFeed::retryLater()
{
	if (!m_wanted)
		return;
	if (m_video) {
		m_video->disconnect(this);
		m_video->kill();
		m_video->deleteLater();
		m_video = nullptr;
	}
	m_pending.clear();
	m_frameBytes = 0;
	m_retry->start(m_retryMs);
	// Backed off so a camera that is genuinely gone does not reconnect in a tight loop for
	// days, and reset by the first frame that arrives.
	m_retryMs = qMin(m_retryMs * 2, kMaximumRetryMs);
}

void CameraFeed::spawnVideo()
{
	if (!m_wanted || m_url.isEmpty())
		return;

	m_frames = 0;
	m_reportedFirst = false;
	m_pending.clear();
	m_frameBytes = 0;
	m_since.start();
	m_lastFrame.start();
	setHealth(QStringLiteral("connecting"), QString());

	// -nostats because the periodic progress line is one log line a second per camera, and
	// -loglevel info because the output header below it is where the pipe's geometry is read
	// from. -fps_mode passthrough is not a tuning knob: a rawvideo pipe carries no timestamps,
	// so the default pads it to a constant rate and every duplicate is decoded, copied and
	// uploaded for nothing.
	QStringList args{"-hide_banner", "-nostdin", "-nostats", "-loglevel", "info"};
	if (m_transport != QStringLiteral("auto"))
		args << "-rtsp_transport" << m_transport;
	args << "-i" << m_url << "-an" << "-fps_mode" << "passthrough"
	     << "-f" << "rawvideo" << "-pix_fmt" << "yuv420p" << "-";

	m_video = new QProcess(this);
	m_video->setProcessChannelMode(QProcess::SeparateChannels);
	connect(m_video, &QProcess::readyReadStandardError, this, &CameraFeed::onVideoStderr);
	connect(m_video, &QProcess::readyReadStandardOutput, this, &CameraFeed::onVideoStdout);
	connect(m_video, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
		// The commonest one by far is "no such program", and it says so: ffmpeg is a package
		// dependency that dh_shlibdeps cannot see - docs/packaging.md.
		setHealth(QStringLiteral("failed"), m_video->errorString());
		retryLater();
	});
	connect(m_video, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
		setHealth(QStringLiteral("failed"), QString("ffmpeg exited %1").arg(code));
		retryLater();
	});

	m_video->start(QStringLiteral("ffmpeg"), args);
	m_watchdog->start();
}

// ffmpeg is the only authority on the geometry of the pipe it is writing.
void CameraFeed::onVideoStderr()
{
	// Two digits minimum on each side, or the FourCC in `rawvideo (I420 / 0x30323449)` is read
	// as the resolution and every frame after it is zero bytes long.
	static const QRegularExpression geometry(R"(Video: rawvideo.*?\b(\d{2,5})x(\d{2,5})\b)");

	const QString text = QString::fromUtf8(m_video->readAllStandardError());
	for (const QString& line : text.split('\n', Qt::SkipEmptyParts)) {
		const QString trimmed = line.trimmed();
		LOG_DEBUG(applog::App) << "[camera] " << m_label.toStdString() << ": "
		                       << trimmed.toStdString();

		if (m_frameBytes > 0)
			continue;
		const auto match = geometry.match(trimmed);
		if (!match.hasMatch())
			continue;
		const QSize size(match.captured(1).toInt(), match.captured(2).toInt());
		// yuv420p halves both axes for the chroma planes, so an odd side has no whole-byte
		// representation and the pipe would be sliced a row short of the picture forever.
		if (size.width() < 16 || size.height() < 16 || size.width() % 2 || size.height() % 2) {
			setHealth(QStringLiteral("failed"),
			          QString("ffmpeg announced an unusable %1x%2 pipe")
			              .arg(size.width()).arg(size.height()));
			retryLater();
			return;
		}
		m_size = size;
		m_frameBytes = m_size.width() * m_size.height() * 3 / 2;
	}
}

void CameraFeed::onVideoStdout()
{
	m_pending += m_video->readAllStandardOutput();

	// Nothing can be sliced before ffmpeg has said what it is writing. The output header comes
	// before the first frame, so this holds at most one frame's worth.
	if (m_frameBytes <= 0 || m_pending.size() < m_frameBytes)
		return;

	// Only the newest whole frame is drawn. A scene that draws slower than the camera sends
	// otherwise grows this buffer without bound, and every frame in it is already stale.
	const int whole = m_pending.size() / m_frameBytes;
	deliver(m_pending.constData() + qsizetype(whole - 1) * m_frameBytes);
	m_pending.remove(0, qsizetype(whole) * m_frameBytes);
}

void CameraFeed::deliver(const char* data)
{
	if (!m_video_sink) {
		setHealth(QStringLiteral("failed"), QStringLiteral("no video sink - the scene attached none"));
		return;
	}

	QVideoFrame frame{QVideoFrameFormat(m_size, QVideoFrameFormat::Format_YUV420P)};
	if (!frame.map(QVideoFrame::WriteOnly)) {
		setHealth(QStringLiteral("failed"), QStringLiteral("cannot map a video frame"));
		return;
	}

	const int width[3]  = {m_size.width(), m_size.width() / 2, m_size.width() / 2};
	const int height[3] = {m_size.height(), m_size.height() / 2, m_size.height() / 2};

	// Row by row, because the mapped plane's stride is Qt's and the pipe's is the picture's -
	// a straight memcpy of the plane shears every frame on any width Qt chose to pad.
	qsizetype read = 0;
	for (int plane = 0; plane < 3; ++plane) {
		uchar*          dst    = frame.bits(plane);
		const qsizetype stride = frame.bytesPerLine(plane);
		for (int y = 0; y < height[plane]; ++y)
			std::memcpy(dst + y * stride, data + read + qsizetype(y) * width[plane],
			            size_t(width[plane]));
		read += qsizetype(width[plane]) * height[plane];
	}

	frame.unmap();
	// Counted by attach()'s connection to the sink, which this fires.
	m_video_sink->setVideoFrame(frame);
}

void CameraFeed::noteFrame()
{
	m_frames++;
	m_lastFrame.restart();
	// m_since is invalid when nothing here spawned the child that is filling the sink, which
	// is how tools/rtsp-probe borrows this object to count another backend's frames.
	if (!m_reportedFirst && m_since.isValid()) {
		m_reportedFirst = true;
		LOG_INFO(applog::App) << "[camera] " << m_label.toStdString() << ": first frame after "
		                      << m_since.elapsed() << " ms";
	}
	setHealth(QStringLiteral("live"), QString());
	emit changed();
}

// A second RTSP session, and deliberately so. One pipe carries one output, and giving the
// video pipe a second consumer - a fifo, a second output - means a reader that falls behind
// stops the picture. This one exists only while somebody is listening, which is at most one
// camera in the application, and it costs the RTSP open below - about a third of a second.
void CameraFeed::spawnAudio()
{
	if (m_audio || m_url.isEmpty())
		return;

	// -allowed_media_types audio, and -vn is not a substitute: -vn drops the video AFTER the
	// demuxer has resolved every track it set up, so without this the sound waits on the H.264
	// track's parameters - a keyframe - and arrives seconds late with nothing reporting it.
	QStringList args{"-hide_banner", "-nostdin", "-nostats", "-loglevel", "warning",
	                 "-allowed_media_types", "audio"};
	if (m_transport != QStringLiteral("auto"))
		args << "-rtsp_transport" << m_transport;
	args << "-i" << m_url << "-vn" << "-map" << "0:a:0?"
	     << "-f" << "s16le" << "-ar" << QString::number(kAudioRate)
	     << "-ac" << QString::number(kAudioChannels) << "-";

	m_audio = new QProcess(this);
	m_audio->setProcessChannelMode(QProcess::SeparateChannels);
	connect(m_audio, &QProcess::readyReadStandardError, this, [this] {
		const QString text = QString::fromUtf8(m_audio->readAllStandardError()).trimmed();
		if (!text.isEmpty())
			LOG_DEBUG(applog::App) << "[camera] " << m_label.toStdString() << " audio: "
			                       << text.toStdString();
	});

	// The sink is opened on the first byte and not at start(). QAudioSink pulls, and one
	// started against a process that has not connected yet spends the whole RTSP open in
	// underrun - which some backends answer by stopping for good.
	connect(m_audio, &QProcess::readyReadStandardOutput, this, [this] {
		if (m_sink)
			return;
		QAudioFormat format;
		format.setSampleRate(kAudioRate);
		format.setChannelCount(kAudioChannels);
		format.setSampleFormat(QAudioFormat::Int16);
		m_sink = new QAudioSink(QMediaDevices::defaultAudioOutput(), format, this);
		m_sink->start(m_audio);
		LOG_INFO(applog::App) << "[camera] " << m_label.toStdString() << ": audio open";
	});

	connect(m_audio, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
		// Not a tile failure and not retried: a camera with no microphone ends here every
		// time it is zoomed, and the picture is unaffected either way.
		LOG_INFO(applog::App) << "[camera] " << m_label.toStdString() << ": audio ended (" << code << ")";
	});

	m_audio->start(QStringLiteral("ffmpeg"), args);
}

void CameraFeed::killAudio()
{
	if (m_audio || m_sink)
		LOG_INFO(applog::App) << "[camera] " << m_label.toStdString() << ": audio closed";
	if (m_sink) {
		m_sink->stop();
		m_sink->deleteLater();
		m_sink = nullptr;
	}
	if (m_audio) {
		m_audio->disconnect(this);
		m_audio->kill();
		m_audio->deleteLater();
		m_audio = nullptr;
	}
}
