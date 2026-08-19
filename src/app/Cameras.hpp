#pragma once

#include <QObject>
#include <QStringList>

// The camera-url list, and nothing else. The tiles are a Repeater over it, so five URLs
// means five tiles and an empty list means none - there is no fixed count anywhere.
//
// Everything about actually playing a stream lives in CameraTile.qml; see docs/media.md for
// why the audio on these is muted rather than simply unconnected.
class Cameras : public QObject {
	Q_OBJECT
	Q_PROPERTY(QStringList urls READ urls CONSTANT)

public:
	explicit Cameras(QStringList urls, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }

private:
	QStringList m_urls;
};
