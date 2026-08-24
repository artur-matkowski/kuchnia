#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QObject>
#include <QSize>
#include <QString>

class QAudioSink;
class QProcess;
class QTimer;
class QVideoSink;

// One camera, decoded by ffmpeg and drawn by Qt. See docs/media.md.
//
// Two child processes, never one: a pipe carries a single output, and the video pipe is the
// one that must not be made to wait. Video runs for as long as the tile is on screen; audio
// runs only while `audible`, which is at most one camera in the whole application.
//
// Instantiable from QML - registered in AppState.cpp with the singletons, because that file
// is where every name the scene resolves is registered.
class CameraFeed : public QObject {
	Q_OBJECT

	Q_PROPERTY(QString url READ url WRITE setUrl NOTIFY configChanged)
	Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY configChanged)
	Q_PROPERTY(QString transport READ transport WRITE setTransport NOTIFY configChanged)

	// Whether this camera may be heard. Writing it starts or kills the audio child outright:
	// there is no mute, and silence is the absence of a process.
	Q_PROPERTY(bool audible READ audible WRITE setAudible NOTIFY audibleChanged)

	// "connecting", "live" or "failed", as StatusBadge renders them.
	Q_PROPERTY(QString health READ health NOTIFY changed)
	Q_PROPERTY(QString detail READ detail NOTIFY changed)
	Q_PROPERTY(int frames READ frames NOTIFY changed)

public:
	explicit CameraFeed(QObject* parent = nullptr);
	~CameraFeed() override;

	QString url() const { return m_url; }
	QString label() const { return m_label; }
	QString transport() const { return m_transport; }
	bool    audible() const { return m_audible; }
	QString health() const { return m_health; }
	QString detail() const { return m_detail; }
	int     frames() const { return m_frames; }

	void setUrl(const QString& url);
	void setLabel(const QString& label);
	void setTransport(const QString& transport);
	void setAudible(bool audible);

	// The sink is CONSTANT on VideoOutput and cannot be assigned, so the scene hands it over
	// rather than this taking one. Frames are counted off its videoFrameChanged, which is the
	// only counter - a second one anywhere counts every frame twice.
	Q_INVOKABLE void attach(QVideoSink* sink);

	// Idempotent, both of them. start() before attach() decodes frames with nowhere to put
	// them; the scene calls attach() in Component.onCompleted and start() after it.
	Q_INVOKABLE void start();
	Q_INVOKABLE void stop(const QString& why);

signals:
	void changed();
	void configChanged();
	void audibleChanged();

private:
	void spawnVideo();
	void spawnAudio();
	void killAudio();
	void retryLater();
	void setHealth(const QString& health, const QString& detail);
	void onVideoStderr();
	void onVideoStdout();
	void noteFrame();
	void deliver(const char* data);

	QString m_url;
	QString m_label;
	QString m_transport = QStringLiteral("tcp");
	bool    m_audible   = false;

	QProcess*   m_video = nullptr;
	QProcess*   m_audio = nullptr;
	QAudioSink* m_sink  = nullptr;
	QVideoSink* m_video_sink = nullptr;
	QTimer*     m_watchdog = nullptr;
	QTimer*     m_retry = nullptr;

	// Whether the tile wants a picture at all. Distinct from whether a child is running: a
	// stream between a failure and its retry is wanted and absent, and the watchdog must not
	// report a tile that was deliberately stopped.
	bool m_wanted = false;

	// Written once per child, from ffmpeg's own description of the pipe it is about to write.
	// Nothing here guesses it - a frame size that disagrees with the bytes arriving is a
	// sheared, rolling picture that reports nothing.
	QSize m_size;
	int   m_frameBytes = 0;

	QByteArray    m_pending;
	QString       m_health = QStringLiteral("connecting");
	QString       m_detail;
	int           m_frames = 0;
	int           m_retryMs = 1000;
	QElapsedTimer m_since;
	QElapsedTimer m_lastFrame;
	bool          m_reportedFirst = false;
};
