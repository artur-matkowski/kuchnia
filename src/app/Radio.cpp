#include "Radio.hpp"

#include <QFile>
#include <QTextStream>

#include "integrations/Log.hpp"

Radio::Radio(QString playlist, QObject* parent)
	: QObject(parent)
	, m_playlist(std::move(playlist))
{
	load();
}

// Extended M3U, and only the two things the scene shows: the text after the last comma of an
// #EXTINF line is the station's name, and the next line that is neither blank nor a directive
// is its URL. Everything else in the file - tvg-logo, group-title, #EXTM3U itself - is a tag
// for other players and is skipped.
//
// A URL with no #EXTINF above it is labelled with the URL. It is a station somebody added by
// hand, and dropping it would be a playlist that is quietly shorter than the file.
void Radio::load()
{
	QFile file(m_playlist);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
		LOG_ERROR(applog::App) << "radio-m3u " << m_playlist.toStdString()
		                       << " cannot be read - the radio has no stations";
		return;
	}

	QTextStream stream(&file);
	QString pending;

	while (!stream.atEnd()) {
		const QString line = stream.readLine().trimmed();
		if (line.isEmpty())
			continue;

		if (line.startsWith('#')) {
			if (line.startsWith("#EXTINF:")) {
				const int comma = line.lastIndexOf(',');
				pending = comma < 0 ? QString() : line.mid(comma + 1).trimmed();
			}
			continue;
		}

		m_urls.append(line);
		m_names.append(pending.isEmpty() ? line : pending);
		pending.clear();
	}

	if (m_urls.isEmpty()) {
		LOG_ERROR(applog::App) << "radio-m3u " << m_playlist.toStdString()
		                       << " holds no stations";
		return;
	}

	LOG_INFO(applog::App) << m_urls.size() << " station(s) from " << m_playlist.toStdString();
}

QString Radio::url() const
{
	return m_index >= 0 && m_index < m_urls.size() ? m_urls.at(m_index) : QString();
}

QString Radio::name() const
{
	return m_index >= 0 && m_index < m_names.size() ? m_names.at(m_index) : QString();
}

void Radio::setIndex(int index)
{
	// Clamped rather than rejected: the remembered station is written by the scene and read
	// back on the next run, and the playlist it was an index into may have been edited since.
	if (m_urls.isEmpty())
		index = 0;
	else
		index = qBound(0, index, m_urls.size() - 1);

	if (index == m_index)
		return;
	m_index = index;
	emit indexChanged();
}

void Radio::next()
{
	if (!m_urls.isEmpty())
		setIndex((m_index + 1) % m_urls.size());
}

void Radio::previous()
{
	if (!m_urls.isEmpty())
		setIndex((m_index + m_urls.size() - 1) % m_urls.size());
}
