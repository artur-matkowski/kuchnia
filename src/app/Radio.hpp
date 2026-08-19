#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// The station list read from radio-m3u, and which station is selected.
//
// This class does not play anything: RadioPanel.qml owns the MediaPlayer, and this is only
// what it is pointed at. The radio is the one thing in the scene with an audio output, which
// is why every camera tile mutes its own - see docs/media.md.
//
// index is clamped to the list, so a remembered station from a longer list cannot leave the
// panel pointed at a URL that no longer exists.
class Radio : public QObject {
	Q_OBJECT
	Q_PROPERTY(QStringList urls READ urls CONSTANT)
	Q_PROPERTY(QStringList names READ names CONSTANT)
	Q_PROPERTY(int count READ count CONSTANT)
	Q_PROPERTY(QString playlist READ playlist CONSTANT)
	Q_PROPERTY(int index READ index WRITE setIndex NOTIFY indexChanged)
	Q_PROPERTY(QString url READ url NOTIFY indexChanged)
	Q_PROPERTY(QString name READ name NOTIFY indexChanged)

public:
	// Reads the playlist here rather than being handed a parsed list: the file is the whole of
	// the station configuration, and a path that cannot be read is a radio with no stations
	// and an error in the log, never a silently empty panel.
	explicit Radio(QString playlist, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }
	QStringList names() const { return m_names; }
	int         count() const { return m_urls.size(); }
	QString     playlist() const { return m_playlist; }
	int         index() const { return m_index; }
	QString     url() const;
	QString     name() const;

	void setIndex(int index);

	Q_INVOKABLE void next();
	Q_INVOKABLE void previous();

signals:
	void indexChanged();

private:
	void load();

	QString     m_playlist;
	QStringList m_urls;
	QStringList m_names;
	int         m_index = 0;
};
