#include "PeopleModel.hpp"

#include <QSet>

#include <cmath>

int PeopleModel::rowCount(const QModelIndex& parent) const
{
	// A list model has rows only at the root; a valid parent means a tree, and answering
	// anything but zero there makes a view ask for children that do not exist.
	if (parent.isValid())
		return 0;
	return static_cast<int>(m_rows.size());
}

QVariant PeopleModel::data(const QModelIndex& index, int role) const
{
	if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
		return QVariant();

	const Row& row = m_rows.at(index.row());
	switch (role) {
	case IdRole:        return row.id;
	case NameRole:      return row.name;
	case LatitudeRole:  return row.latitude;
	case LongitudeRole: return row.longitude;
	case AccuracyRole:  return row.accuracy;
	case SeenAtRole:    return row.seenAt;
	case BatteryRole:   return row.battery;
	case StackRole:     return row.stack;
	default:            return QVariant();
	}
}

QHash<int, QByteArray> PeopleModel::roleNames() const
{
	// These names are what the delegate reads. A role missing from this hash is not an error
	// anywhere: it is simply a name QML never resolves, and `model.latitude` becomes
	// undefined - which QtPositioning.coordinate() turns into a marker at NaN, drawn nowhere.
	return {
		{IdRole,        "personId"},
		{NameRole,      "name"},
		{LatitudeRole,  "latitude"},
		{LongitudeRole, "longitude"},
		{AccuracyRole,  "accuracy"},
		{SeenAtRole,    "seenAt"},
		{BatteryRole,   "battery"},
		{StackRole,     "stackIndex"},
	};
}

void PeopleModel::set(const std::vector<Person>& people)
{
	QSet<QString> incoming;
	incoming.reserve(static_cast<int>(people.size()));
	for (const Person& person : people)
		incoming.insert(QString::fromStdString(person.id));

	// Backwards, so an index is still valid after the row above it went. Forwards would skip
	// the row that slid into the one just removed.
	for (int i = m_rows.size() - 1; i >= 0; --i) {
		if (incoming.contains(m_rows.at(i).id))
			continue;
		beginRemoveRows(QModelIndex(), i, i);
		m_rows.remove(i);
		endRemoveRows();
	}

	for (const Person& person : people) {
		const QString id = QString::fromStdString(person.id);

		int at = -1;
		for (int i = 0; i < m_rows.size(); ++i) {
			if (m_rows.at(i).id == id) {
				at = i;
				break;
			}
		}

		Row row;
		row.id        = id;
		row.name      = QString::fromStdString(person.name);
		row.latitude  = person.latitude;
		row.longitude = person.longitude;
		row.accuracy  = person.accuracy;
		row.seenAt    = person.seenAt * 1000.0;
		row.battery   = person.battery;

		if (at < 0) {
			const int end = m_rows.size();
			beginInsertRows(QModelIndex(), end, end);
			m_rows.append(row);
			endInsertRows();
			continue;
		}

		// In place, and only the roles that moved. Emitting every role on every poll would
		// re-evaluate every binding in every delegate, which is most of what the model exists
		// to avoid; emitting none at all leaves a marker drawn where the person no longer is.
		Row& current = m_rows[at];
		QVector<int> changed;
		if (current.name != row.name)           changed << NameRole;
		if (current.latitude != row.latitude)   changed << LatitudeRole;
		if (current.longitude != row.longitude) changed << LongitudeRole;
		if (current.accuracy != row.accuracy)   changed << AccuracyRole;
		if (current.seenAt != row.seenAt)       changed << SeenAtRole;
		if (current.battery != row.battery)     changed << BatteryRole;

		if (changed.isEmpty())
			continue;

		// restack() owns `stack` and runs after this loop; `row` was built from the service's
		// answer, which carries no such field. Assigning it here would reset every rung to 0
		// on every poll, and restack() would then emit dataChanged for all of them.
		row.stack = current.stack;
		current = row;
		const QModelIndex at_ = index(at);
		emit dataChanged(at_, at_, changed);
	}

	restack();
}

namespace {

// How far apart two people can be and still get one label rung each instead of two boxes on
// the same pixels. A claim about labels colliding, not a distance: both markers stay on their
// own coordinates and only the boxes move.
//
// Wide enough to hold a household together through GPS jitter. Observed fixes for two phones
// in one house carry accuracy_m of 67-100 and wander tens of metres between polls, so a
// threshold tight enough to let those separate is a pair of boxes that jump apart and back
// every minute - which reads as a bug rather than as movement.
constexpr double kSamePlaceDegrees = 0.001;  // ~110 m of latitude, ~70 m of longitude at 52N

}  // namespace

void PeopleModel::restack()
{
	// Single linkage, in row order, rather than rounding coordinates onto a grid: a grid puts
	// two people either side of a cell edge into different cells while they are drawn on the
	// same pixel, and that collision is exactly what this exists to prevent - it would report
	// nothing. Rows are a household, so the honest version costs nothing worth measuring.
	QVector<int> cluster(m_rows.size(), -1);
	QVector<int> height;  // how many rungs each cluster has used

	for (int i = 0; i < m_rows.size(); ++i) {
		for (int j = 0; j < i; ++j) {
			if (std::abs(m_rows.at(i).latitude - m_rows.at(j).latitude) > kSamePlaceDegrees)
				continue;
			if (std::abs(m_rows.at(i).longitude - m_rows.at(j).longitude) > kSamePlaceDegrees)
				continue;
			cluster[i] = cluster[j];
			break;
		}

		if (cluster[i] < 0) {
			cluster[i] = height.size();
			height.append(0);
		}

		const int stack = height[cluster[i]]++;
		if (m_rows.at(i).stack == stack)
			continue;

		m_rows[i].stack = stack;
		const QModelIndex at = index(i);
		emit dataChanged(at, at, {StackRole});
	}
}
