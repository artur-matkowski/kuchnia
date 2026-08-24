#include "Feed.hpp"

#include <cstring>

#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QVideoSink>

namespace {

// The same two budgets CameraTile.qml carries, so a run of this tool and a run of the
// application are read against one clock.
constexpr int kConnectTimeoutMs = 20000;
constexpr int kStallTimeoutMs   = 5000;

} // namespace

Feed::Feed(QString url, QString label, QString transport, QObject* parent)
	: QObject(parent)
	, m_url(std::move(url))
	, m_label(std::move(label))
	, m_transport(std::move(transport))
{
}

Feed::~Feed()
{
	if (m_ffmpeg && m_ffmpeg->state() != QProcess::NotRunning) {
		m_ffmpeg->kill();
		m_ffmpeg->waitForFinished(2000);
	}
}

void Feed::attach(QVideoSink* sink)
{
	m_sink = sink;
	// The one place frames are counted, whichever backend put them there. Wiring this from
	// QML instead put it inside the Loader that builds the Qt backend, where it silently
	// never fired.
	connect(sink, &QVideoSink::videoFrameChanged, this, &Feed::noteFrame);
}

// Idempotent: whichever of noteAsked() and start() runs first owns the clock.
void Feed::armClocks()
{
	if (m_watchdog)
		return;

	m_since.start();
	m_lastFrame.start();

	m_watchdog = new QTimer(this);
	m_watchdog->setInterval(1000);
	connect(m_watchdog, &QTimer::timeout, this, [this] {
		const int budget = m_frames == 0 ? kConnectTimeoutMs : kStallTimeoutMs;
		if (m_lastFrame.elapsed() < budget)
			return;
		setHealth("failed", m_frames == 0 ? "no first frame" : "stalled");
	});
	m_watchdog->start();
}

void Feed::noteAsked()
{
	armClocks();
}

void Feed::noteFrame()
{
	m_frames++;
	m_lastFrame.restart();
	if (!m_reportedFirst) {
		m_reportedFirst = true;
		qInfo().noquote() << "[feed]" << m_label << ": first frame after" << m_since.elapsed() << "ms";
	}
	setHealth("live", QString());
	emit changed();
}

void Feed::setHealth(const QString& health, const QString& detail)
{
	if (m_health == health && m_detail == detail)
		return;
	m_health = health;
	m_detail = detail;
	qInfo().noquote() << "[feed]" << m_label << ":" << health
	                  << (detail.isEmpty() ? QString() : "(" + detail + ")");
	emit changed();
}

void Feed::start()
{
	armClocks();

	QStringList args{"-hide_banner", "-nostdin", "-loglevel", "info"};
	if (m_transport != "auto")
		args << "-rtsp_transport" << m_transport;
	// -an because this is the video path under test, and an audio stream on the pipe would
	// have to be demultiplexed back out of it - which is the work being avoided.
	//
	// -fps_mode passthrough is not a tuning knob. A rawvideo pipe carries no timestamps, so
	// ffmpeg's default is to pad it to a constant rate: a camera sending 10 fps at a declared
	// 25 arrives as 25 fps of which 15 are duplicates. The tile still looks right, and the
	// frame count this tool exists to compare against Qt's is inflated by half.
	args << "-i" << m_url << "-an" << "-fps_mode" << "passthrough"
	     << "-stats_period" << "5"
	     << "-f" << "rawvideo" << "-pix_fmt" << "yuv420p" << "-";

	m_ffmpeg = new QProcess(this);
	m_ffmpeg->setProcessChannelMode(QProcess::SeparateChannels);
	connect(m_ffmpeg, &QProcess::readyReadStandardError, this, &Feed::onStderr);
	connect(m_ffmpeg, &QProcess::readyReadStandardOutput, this, &Feed::onStdout);
	connect(m_ffmpeg, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
		setHealth("failed", m_ffmpeg->errorString());
	});
	// No restart. A stream that dies and is silently reopened is the measurement this tool
	// exists to take, erased - the application already retries, and what it costs is the
	// question.
	connect(m_ffmpeg, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
		setHealth("failed", QString("ffmpeg exited %1").arg(code));
	});

	m_ffmpeg->start("ffmpeg", args);
}

// ffmpeg is the only authority on the geometry of the pipe it is writing. Reading it from
// anywhere else - a prior ffprobe, a configured size - is an assumption, and a frame size that
// disagrees with the bytes arriving is a sheared, rolling picture that reports nothing.
void Feed::onStderr()
{
	// Two digits minimum on each side, or the FourCC in `rawvideo (I420 / 0x30323449)` is
	// read as a 0x30323449 picture and every frame after it is zero bytes long.
	static const QRegularExpression geometry(R"(Video: rawvideo.*?\b(\d{2,5})x(\d{2,5})\b)");

	const QString text = QString::fromUtf8(m_ffmpeg->readAllStandardError());
	for (const QString& line : text.split('\n', Qt::SkipEmptyParts)) {
		const QString trimmed = line.trimmed();
		qInfo().noquote() << "[ffmpeg]" << m_label << ":" << trimmed;

		if (m_frameBytes > 0)
			continue;
		const auto match = geometry.match(trimmed);
		if (!match.hasMatch())
			continue;
		const QSize size(match.captured(1).toInt(), match.captured(2).toInt());
		// yuv420p halves both axes for the chroma planes, so an odd side has no whole-byte
		// representation and the pipe would be sliced a row short of the picture forever.
		if (size.width() < 16 || size.height() < 16 || size.width() % 2 || size.height() % 2) {
			setHealth("failed", QString("ffmpeg announced an unusable %1x%2 pipe")
			                        .arg(size.width()).arg(size.height()));
			continue;
		}
		m_size = size;
		// yuv420p: a full-size luma plane and two half-size chroma planes.
		m_frameBytes = m_size.width() * m_size.height() * 3 / 2;
		qInfo().noquote() << "[feed]" << m_label << ": pipe carries"
		                  << m_size.width() << "x" << m_size.height()
		                  << "yuv420p," << m_frameBytes << "bytes per frame";
	}
}

void Feed::onStdout()
{
	m_pending += m_ffmpeg->readAllStandardOutput();

	// Nothing can be sliced before ffmpeg has said what it is writing. It prints the output
	// header before the first frame, so this holds at most one frame's worth.
	if (m_frameBytes <= 0)
		return;

	if (m_pending.size() < m_frameBytes)
		return;

	// Only the newest whole frame is shown. A scene that draws slower than the camera sends
	// otherwise grows this buffer without bound, and every frame in it is already stale.
	const int whole = m_pending.size() / m_frameBytes;
	deliver(m_pending.constData() + qsizetype(whole - 1) * m_frameBytes);
	m_pending.remove(0, qsizetype(whole) * m_frameBytes);
}

void Feed::deliver(const char* data)
{
	if (!m_sink) {
		setHealth("failed", "no video sink - the scene never attached one");
		return;
	}

	QVideoFrame frame{QVideoFrameFormat(m_size, QVideoFrameFormat::Format_YUV420P)};
	if (!frame.map(QVideoFrame::WriteOnly)) {
		setHealth("failed", "cannot map a video frame");
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
			std::memcpy(dst + y * stride, data + read + qsizetype(y) * width[plane], size_t(width[plane]));
		read += qsizetype(width[plane]) * height[plane];
	}

	frame.unmap();
	// Counted by attach()'s connection to the sink, which this fires.
	m_sink->setVideoFrame(frame);
}
