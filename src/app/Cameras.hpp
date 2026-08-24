#pragma once

#include <QObject>
#include <QStringList>

// The camera-url list, how long a tile holds its stream off screen, and which RTSP transport
// is asked for.
//
// Playing a stream is CameraFeed's; drawing one is CameraTile.qml's. See docs/media.md.
class Cameras : public QObject {
	Q_OBJECT
	Q_PROPERTY(QStringList urls READ urls CONSTANT)
	Q_PROPERTY(int holdMs READ holdMs CONSTANT)
	Q_PROPERTY(QString transport READ transport CONSTANT)

public:
	Cameras(QStringList urls, int holdMs, QString transport, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }
	int holdMs() const { return m_holdMs; }
	QString transport() const { return m_transport; }

private:
	QStringList m_urls;
	int         m_holdMs;
	QString     m_transport;
};
