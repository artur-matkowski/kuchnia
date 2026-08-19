#pragma once

#include "Panel.hpp"
#include "Series.hpp"

// The domestic hot water tank: the current temperature and the window behind it.
//
// current is only meaningful while status is "live". It keeps its last value through a
// failure rather than resetting to zero, because a gauge that swings to zero reads as cold
// water rather than as no reading - the status is what says which it is.
class HotWater : public Panel {
	Q_OBJECT
	Q_PROPERTY(double current READ current NOTIFY currentChanged)
	Q_PROPERTY(ChartSeries history READ history NOTIFY historyChanged)

public:
	using Panel::Panel;

	double      current() const { return m_current; }
	ChartSeries history() const { return m_history; }

	// GUI thread only.
	void update(const HotWaterUpdate& update);

signals:
	void currentChanged();
	void historyChanged();

private:
	double      m_current = 0.0;
	ChartSeries m_history;
};
