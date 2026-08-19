#pragma once

#include <QObject>
#include <QStringList>

// The camera-url list and how long a tile holds its stream off screen.
//
// Everything about actually playing a stream lives in CameraTile.qml; see docs/media.md for
// why the audio on these is muted rather than simply unconnected, and what holdMs buys.
class Cameras : public QObject {
	Q_OBJECT
	Q_PROPERTY(QStringList urls READ urls CONSTANT)
	Q_PROPERTY(int holdMs READ holdMs CONSTANT)

public:
	Cameras(QStringList urls, int holdMs, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }
	int holdMs() const { return m_holdMs; }

private:
	QStringList m_urls;
	int         m_holdMs;
};
