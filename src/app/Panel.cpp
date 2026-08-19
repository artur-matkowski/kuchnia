#include "Panel.hpp"

void Panel::setHealth(Health health, const QString& detail)
{
	QString next;
	switch (health) {
	case Health::Connecting: next = QStringLiteral("connecting"); break;
	case Health::Live:       next = QStringLiteral("live"); break;
	case Health::Failed:     next = QStringLiteral("failed"); break;
	}

	if (next == m_status && detail == m_statusDetail)
		return;

	m_status = next;
	m_statusDetail = detail;
	emit statusChanged();
}
