#include "Series.hpp"

#include <QPointF>

ChartSeries ChartSeries::from(const Series& samples)
{
	ChartSeries out;
	if (samples.empty())
		return out;

	out.xMin = out.xMax = samples.front().time * 1000.0;
	out.yMin = out.yMax = samples.front().value;

	out.points.reserve(static_cast<int>(samples.size()));
	for (const Sample& sample : samples) {
		const double x = sample.time * 1000.0;
		out.points.append(QPointF(x, sample.value));
		out.xMin = qMin(out.xMin, x);
		out.xMax = qMax(out.xMax, x);
		out.yMin = qMin(out.yMin, sample.value);
		out.yMax = qMax(out.yMax, sample.value);
	}
	return out;
}

QVariantList ChartSeries::listFrom(const std::vector<Series>& series)
{
	QVariantList out;
	out.reserve(static_cast<int>(series.size()));
	for (const Series& samples : series)
		out.append(QVariant::fromValue(from(samples)));
	return out;
}

QVariantList DaylightBand::listFrom(const std::vector<Daylight>& bands)
{
	QVariantList out;
	out.reserve(static_cast<int>(bands.size()));
	for (const Daylight& band : bands) {
		DaylightBand entry;
		entry.from = band.from * 1000.0;
		entry.to   = band.to * 1000.0;
		out.append(QVariant::fromValue(entry));
	}
	return out;
}
