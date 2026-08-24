#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QObject>
#include <QSize>
#include <QString>

class QProcess;
class QTimer;
class QVideoSink;

// One RTSP stream carried into the scene without Qt demuxing or decoding any of it.
//
// ffmpeg runs as a child process and writes raw yuv420p frames down a pipe; this slices the
// pipe into QVideoFrames and hands them to the QVideoSink a QML VideoOutput gave us. Qt's
// only remaining job is the blit. See docs/rtsp.md.
class Feed : public QObject {
	Q_OBJECT
	Q_PROPERTY(QString label READ label CONSTANT)
	Q_PROPERTY(QString url READ url CONSTANT)
	Q_PROPERTY(QString health READ health NOTIFY changed)
	Q_PROPERTY(QString detail READ detail NOTIFY changed)
	Q_PROPERTY(int frames READ frames NOTIFY changed)

public:
	Feed(QString url, QString label, QString transport, QObject* parent = nullptr);
	~Feed() override;

	QString label() const { return m_label; }
	QString url() const { return m_url; }
	QString health() const { return m_health; }
	QString detail() const { return m_detail; }
	int     frames() const { return m_frames; }

	// The sink belongs to the VideoOutput and is CONSTANT on it, so the scene hands it over
	// rather than taking one: `Component.onCompleted: feed.attach(output.videoSink)`.
	Q_INVOKABLE void attach(QVideoSink* sink);

	// Both backends are counted off the same signal, on the sink attach() was given: the Qt
	// backend's frames never pass through this object, and a second counter beside this one
	// would report the ffmpeg backend's frames twice.
	void noteFrame();

	// The moment the stream was ASKED for, which is where a first-frame number has to start.
	// The Qt backend calls this immediately before MediaPlayer.play(); the ffmpeg backend's
	// start() calls it itself. Anything else measures window construction as connect time.
	Q_INVOKABLE void noteAsked();

	// Spawns ffmpeg. Called after the scene is loaded, so the sink attach() needs already
	// exists - frames written before there is anywhere to put them are decoded and dropped.
	void start();

signals:
	void changed();

private:
	void armClocks();
	void onStderr();
	void onStdout();
	void setHealth(const QString& health, const QString& detail);
	void deliver(const char* data);

	const QString m_url;
	const QString m_label;
	const QString m_transport;

	QProcess*   m_ffmpeg = nullptr;
	QVideoSink* m_sink   = nullptr;
	QTimer*     m_watchdog = nullptr;

	// Written once, from ffmpeg's own description of the pipe it is about to write. Nothing
	// here guesses the geometry: a frame size that disagrees with the bytes on the pipe is a
	// rolling, sheared picture and never an error.
	QSize m_size;
	int   m_frameBytes = 0;

	QByteArray    m_pending;
	QString       m_health = "connecting";
	QString       m_detail;
	int           m_frames = 0;
	QElapsedTimer m_since;
	QElapsedTimer m_lastFrame;
	bool          m_reportedFirst = false;
};
