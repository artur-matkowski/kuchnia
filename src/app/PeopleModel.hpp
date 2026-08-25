#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QString>
#include <QVector>

#include "integrations/Sinks.hpp"

// The people on the map, as rows.
//
// The only QAbstractListModel in the program, and it earns that: every other list here is a
// QVariantList read by a Repeater, which is fine for a set that is replaced wholesale and
// wrong for one that moves. A Repeater handed a fresh list destroys and re-incubates EVERY
// delegate the moment any value in it changes - see the comment in src/qml/LineChart.qml -
// and a map delegate is a MapQuickItem, so a poll that moved one person would tear down and
// rebuild every marker on screen.
//
// So set() matches incoming rows against the ones already here BY THEIR id and emits
// dataChanged for those, reserving begin/endInsertRows and begin/endRemoveRows for a roster
// that genuinely changed. This is why Sinks.hpp insists the service's id is stable.
//
// Coordinates leave here as plain doubles rather than as QGeoCoordinate: keeping Qt's
// positioning types out of C++ is what keeps Qt6::Positioning off the link line and out of
// debian/control's Build-Depends. The delegate builds the coordinate itself.
class PeopleModel : public QAbstractListModel {
	Q_OBJECT

public:
	enum Role {
		IdRole = Qt::UserRole + 1,
		NameRole,
		LatitudeRole,
		LongitudeRole,
		AccuracyRole,
		SeenAtRole,
		BatteryRole,
	};

	using QAbstractListModel::QAbstractListModel;

	int      rowCount(const QModelIndex& parent = QModelIndex()) const override;
	QVariant data(const QModelIndex& index, int role) const override;
	QHash<int, QByteArray> roleNames() const override;

	// GUI thread only. AppState is what guarantees that.
	void set(const std::vector<Person>& people);

private:
	struct Row {
		QString id;
		QString name;
		double  latitude  = 0.0;
		double  longitude = 0.0;
		double  accuracy  = 0.0;
		// Milliseconds, not the seconds Sinks.hpp carries: this is the side of the seam QML
		// reads, and QML's Date takes milliseconds. The conversion happens here, once.
		double  seenAt    = 0.0;
		int     battery   = -1;
	};

	QVector<Row> m_rows;
};
