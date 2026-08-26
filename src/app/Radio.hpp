#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// The station list read from the radio-m3u playlists, and which station is selected.
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
	Q_PROPERTY(QStringList playlists READ playlists CONSTANT)
	Q_PROPERTY(int index READ index WRITE setIndex NOTIFY indexChanged)
	Q_PROPERTY(QString url READ url NOTIFY indexChanged)
	Q_PROPERTY(QString name READ name NOTIFY indexChanged)

public:
	// Reads the playlists here rather than being handed a parsed list: the files are the whole
	// of the station configuration, and a path that cannot be read is an error in the log and
	// stations missing from the panel, never a silently shorter list.
	explicit Radio(QStringList playlists, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }
	QStringList names() const { return m_names; }
	int         count() const { return m_urls.size(); }
	QStringList playlists() const { return m_playlists; }
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
	void read(const QString& playlist);

	QStringList m_playlists;
	QStringList m_urls;
	QStringList m_names;
	int         m_index = 0;
};
