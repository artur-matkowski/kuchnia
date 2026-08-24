#include "Cameras.hpp"

#include "integrations/Log.hpp"

Cameras::Cameras(QStringList urls, int holdMs, QString transport, QObject* parent)
	: QObject(parent)
	, m_urls(std::move(urls))
	, m_holdMs(holdMs)
	, m_transport(std::move(transport))
{
	// An unset camera-url is a scene with no tiles at all, which looks like a layout bug
	// rather than a configuration one.
	if (m_urls.isEmpty())
		LOG_WARN(applog::App) << "camera-url is empty - no camera tiles will be drawn";

	// ffmpeg takes anything here and only complains when it opens, per camera, in a line the
	// tile turns into "failed" - so a typo is five dead tiles and a reason buried at debug.
	if (m_transport != "tcp" && m_transport != "udp" && m_transport != "auto")
		LOG_WARN(applog::App) << "camera-transport is '" << m_transport.toStdString()
		                      << "' - expected tcp, udp or auto";
}
