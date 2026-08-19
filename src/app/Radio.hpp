#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// The station list from radio-url, and which one is selected.
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
	Q_PROPERTY(int index READ index WRITE setIndex NOTIFY indexChanged)
	Q_PROPERTY(QString url READ url NOTIFY indexChanged)
	Q_PROPERTY(QString name READ name NOTIFY indexChanged)

public:
	Radio(QStringList urls, QStringList names, QObject* parent = nullptr);

	QStringList urls() const { return m_urls; }
	QStringList names() const { return m_names; }
	int         count() const { return m_urls.size(); }
	int         index() const { return m_index; }
	QString     url() const;
	QString     name() const;

	void setIndex(int index);

	Q_INVOKABLE void next();
	Q_INVOKABLE void previous();

signals:
	void indexChanged();

private:
	QStringList m_urls;
	QStringList m_names;
	int         m_index = 0;
};
