#pragma once

#include <QObject>
#include <QString>

#include "integrations/Sinks.hpp"

// What every panel backed by a network client shares: whether its data is trustworthy.
//
// The scene shows this instead of dressing a stale or absent reading up as a real one - a
// chart that has simply stopped moving looks identical to one that is up to date, which is
// the failure this exists to make impossible.
//
// status is a string rather than an enum so QML reads it without a registered type; the
// three values are the only ones ever set.
class Panel : public QObject {
	Q_OBJECT
	Q_PROPERTY(QString status READ status NOTIFY statusChanged)
	Q_PROPERTY(QString statusDetail READ statusDetail NOTIFY statusChanged)
	Q_PROPERTY(bool live READ live NOTIFY statusChanged)

public:
	using QObject::QObject;

	QString status() const { return m_status; }
	QString statusDetail() const { return m_statusDetail; }
	bool    live() const { return m_status == QStringLiteral("live"); }

	// GUI thread only. AppState is what guarantees that.
	void setHealth(Health health, const QString& detail);

signals:
	void statusChanged();

private:
	QString m_status = QStringLiteral("connecting");
	QString m_statusDetail;
};
