#pragma once

#include <functional>

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>

#include "Panel.hpp"
#include "PeopleModel.hpp"

// Everyone sharing a location, and the box that holds all of them.
//
// The bounds are the raw extent of the markers, in degrees, and nothing here pads them: the
// ticket's "+10%" is a property of how the map is framed rather than of where the people
// are, and it is applied once in src/qml/MapScreen.qml where the viewport is set.
//
// `hasBounds` is false whenever there is nobody to bound, and the map must check it. A box
// of four zeroes is a perfectly valid point in the Gulf of Guinea, so a viewport set from
// empty bounds is not a blank map - it is a map of the wrong place, drawn confidently.
class People : public Panel {
	Q_OBJECT
	Q_PROPERTY(QAbstractListModel* model READ model CONSTANT)

	// The map's one setting, carried here because the map has no object of its own and one
	// singleton for one string would be a worse trade. Cameras carries its URLs the same way.
	Q_PROPERTY(QString tileUrl READ tileUrl CONSTANT)
	Q_PROPERTY(int count READ count NOTIFY boundsChanged)
	Q_PROPERTY(bool hasBounds READ hasBounds NOTIFY boundsChanged)
	Q_PROPERTY(double minLatitude READ minLatitude NOTIFY boundsChanged)
	Q_PROPERTY(double maxLatitude READ maxLatitude NOTIFY boundsChanged)
	Q_PROPERTY(double minLongitude READ minLongitude NOTIFY boundsChanged)
	Q_PROPERTY(double maxLongitude READ maxLongitude NOTIFY boundsChanged)

public:
	explicit People(QString tileUrl, QObject* parent = nullptr);

	QAbstractListModel* model() { return &m_model; }
	QString             tileUrl() const { return m_tileUrl; }

	int    count() const { return m_count; }
	bool   hasBounds() const { return m_count > 0; }
	double minLatitude() const { return m_minLatitude; }
	double maxLatitude() const { return m_maxLatitude; }
	double minLongitude() const { return m_minLongitude; }
	double maxLongitude() const { return m_maxLongitude; }

	// GUI thread only. AppState is what guarantees that.
	void update(const PeopleUpdate& people);

	// Cuts the roster poll's wait short, so the map's refresh key re-reads the service rather
	// than sitting out the rest of people-interval-ms. Set from main() once Integrations
	// exists, exactly as the gate's command sink is.
	void setRefreshSink(std::function<void()> sink);

	// Only wakes the worker; the poll itself happens on its thread. Nothing here blocks.
	Q_INVOKABLE void refresh();

	// The roster list's three questions, forwarded to the model. They are here because this is
	// what is registered as the QML singleton - the model reaches QML only as `model`, and a
	// method called through that resolves against the base type it is declared as.
	Q_INVOKABLE QString     idAt(int row) const { return m_model.idAt(row); }
	Q_INVOKABLE int         rowOf(const QString& id) const { return m_model.rowOf(id); }
	Q_INVOKABLE QVariantMap person(const QString& id) const { return m_model.person(id); }

signals:
	void boundsChanged();

private:
	PeopleModel           m_model;
	QString               m_tileUrl;
	std::function<void()> m_refresh;

	int    m_count = 0;
	double m_minLatitude  = 0.0;
	double m_maxLatitude  = 0.0;
	double m_minLongitude = 0.0;
	double m_maxLongitude = 0.0;
};
