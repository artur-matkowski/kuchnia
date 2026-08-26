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
	// NOT CONSTANT, because reload() replaces all three. A CONSTANT property is read once and
	// cached, so the station list would be re-read with the panel still drawing the old one and
	// nothing anywhere would say so.
	Q_PROPERTY(QStringList urls READ urls NOTIFY stationsChanged)
	Q_PROPERTY(QStringList names READ names NOTIFY stationsChanged)
	Q_PROPERTY(int count READ count NOTIFY stationsChanged)
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

	// Re-reads every playlist, for the refresh key - see docs/input.md. The selected station is
	// kept by URL and not by position, so a station inserted above it does not move what is
	// playing; gone from every file, it is stationLost() and the panel stops.
	Q_INVOKABLE void reload();

signals:
	void indexChanged();
	void stationsChanged();

	// The station that was selected is in none of the playlists any more. RadioPanel stops on
	// it, so nothing is left playing that the list no longer offers.
	void stationLost();

private:
	void load();
	void read(const QString& playlist);

	QStringList m_playlists;
	QStringList m_urls;
	QStringList m_names;
	int         m_index = 0;
};
