#include "PeopleModel.hpp"

#include <QSet>

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

		current = row;
		const QModelIndex at_ = index(at);
		emit dataChanged(at_, at_, changed);
	}
}
