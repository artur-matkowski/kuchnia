#include "People.hpp"

#include <algorithm>

People::People(QObject* parent)
	: Panel(parent)
{
}

void People::update(const PeopleUpdate& people)
{
	m_model.set(people.people);

	m_count = static_cast<int>(people.people.size());

	// Recomputed from scratch each poll rather than widened as people move, because a box
	// that only ever grows is a box that keeps a marker's old corner forever: the last person
	// to leave the country would keep the map zoomed out to hold a place nobody is.
	if (m_count > 0) {
		m_minLatitude  = people.people.front().latitude;
		m_maxLatitude  = m_minLatitude;
		m_minLongitude = people.people.front().longitude;
		m_maxLongitude = m_minLongitude;

		for (const Person& person : people.people) {
			m_minLatitude  = std::min(m_minLatitude, person.latitude);
			m_maxLatitude  = std::max(m_maxLatitude, person.latitude);
			m_minLongitude = std::min(m_minLongitude, person.longitude);
			m_maxLongitude = std::max(m_maxLongitude, person.longitude);
		}
	}

	emit boundsChanged();
}
