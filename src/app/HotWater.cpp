#include "HotWater.hpp"

void HotWater::update(const HotWaterUpdate& update)
{
	if (m_current != update.current) {
		m_current = update.current;
		emit currentChanged();
	}

	// No comparison: the series is a poll's worth of points and comparing it costs more than
	// re-binding the chart that reads it.
	m_history = ChartSeries::from(update.history);
	emit historyChanged();
}
