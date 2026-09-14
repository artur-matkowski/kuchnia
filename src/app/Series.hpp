#pragma once

#include <QMetaType>
#include <QObject>
#include <QVariantList>

#include <vector>

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
	static QVariantList listFrom(const std::vector<Series>& series);
};

// One daylight band on its way into QML, in the same milliseconds ChartSeries uses so a
// chart can map both against one window: LineChart.qml reads band.from and band.to.
class DaylightBand {
	Q_GADGET
	Q_PROPERTY(double from MEMBER from CONSTANT)
	Q_PROPERTY(double to MEMBER to CONSTANT)

public:
	double from = 0.0;
	double to   = 0.0;

	static QVariantList listFrom(const std::vector<Daylight>& bands);
};

Q_DECLARE_METATYPE(ChartSeries)
Q_DECLARE_METATYPE(DaylightBand)
