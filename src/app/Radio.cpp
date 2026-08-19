#include "Radio.hpp"

#include "integrations/Log.hpp"

Radio::Radio(QStringList urls, QStringList names, QObject* parent)
	: QObject(parent)
	, m_urls(std::move(urls))
	, m_names(std::move(names))
{
	// loadSettings refuses a radio-name of the wrong length outright, so the only case left
	// is no names at all. Falling back to the URL keeps every station labelled with something
	// a person can tell apart, rather than with an index.
	if (m_names.isEmpty())
		m_names = m_urls;

	if (m_urls.isEmpty())
		LOG_WARN(applog::App) << "radio-url is empty - the radio has nothing to play";
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
	// back on the next run, and the list it was an index into may have been edited since.
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
