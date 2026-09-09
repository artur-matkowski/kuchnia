#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QString>
#include <QVariantMap>
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
		StackRole,
	};

	using QAbstractListModel::QAbstractListModel;

	int      rowCount(const QModelIndex& parent = QModelIndex()) const override;
	QVariant data(const QModelIndex& index, int role) const override;
	QHash<int, QByteArray> roleNames() const override;

	// GUI thread only. AppState is what guarantees that.
	void set(const std::vector<Person>& people);

	// What the map's roster list asks of the rows, reached from QML through People. A row index
	// is what the list walks and an id is what the map follows, because a removal shifts every
	// row below it: an index held across a poll is a different person, silently.
	QString     idAt(int row) const;
	int         rowOf(const QString& id) const;

	// {name, latitude, longitude}, and EMPTY when nobody has that id any more. The empty answer
	// is load-bearing - it is how a followed person who stopped sharing drops the follow rather
	// than leaving the viewport parked on a coordinate they left. Plain doubles, as the roles
	// are: a QGeoCoordinate here puts Qt6::Positioning back on the link line.
	QVariantMap person(const QString& id) const;

private:
	// Numbers everyone at one address 0, 1, 2 so the delegate can lift each label clear of the
	// one below it. Runs after the merge, never inside it: a row's rung depends on rows the
	// merge loop has not reached yet. See docs/map.md.
	void restack();

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

		// Which rung of the stack this person's label sits on, counting up from the marker.
		// Everyone alone somewhere is 0; a household is 0, 1, 2 in row order. Computed from
		// every other row, so it can only be assigned once all of them are in - restack().
		int     stack     = 0;
	};

	QVector<Row> m_rows;
};
