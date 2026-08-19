#include "Cameras.hpp"

#include "integrations/Log.hpp"

Cameras::Cameras(QStringList urls, int holdMs, QObject* parent)
	: QObject(parent)
	, m_urls(std::move(urls))
	, m_holdMs(holdMs)
{
	// An unset camera-url is a scene with no tiles at all, which looks like a layout bug
	// rather than a configuration one.
	if (m_urls.isEmpty())
		LOG_WARN(applog::App) << "camera-url is empty - no camera tiles will be drawn";
}
