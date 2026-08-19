#pragma once

#include <QMetaType>
#include <QObject>
#include <QVariantList>

#include "integrations/Sinks.hpp"

// A time series on its way into QML, plus the bounds a chart needs to scale it. Read from
// QML as one value: HotWater.history.points, HotWater.history.yMax.
//
// Points stay in data space - x is milliseconds since the epoch, y the value's own unit -
// and LineChart.qml maps them to pixels. Converting here would bake the item's size into the
// model and send every resize back through C++.
//
// Milliseconds and not the seconds Sinks.hpp carries, because QML's Date takes milliseconds.
// Doing that multiplication anywhere but here produces an axis labelled 1970.
class ChartSeries {
	Q_GADGET
	Q_PROPERTY(QVariantList points MEMBER points CONSTANT)
	Q_PROPERTY(double xMin MEMBER xMin CONSTANT)
	Q_PROPERTY(double xMax MEMBER xMax CONSTANT)
	Q_PROPERTY(double yMin MEMBER yMin CONSTANT)
	Q_PROPERTY(double yMax MEMBER yMax CONSTANT)

public:
	QVariantList points;
	double       xMin = 0.0;
	double       xMax = 0.0;
	double       yMin = 0.0;
	double       yMax = 0.0;

	static ChartSeries from(const Series& samples);
};

Q_DECLARE_METATYPE(ChartSeries)
