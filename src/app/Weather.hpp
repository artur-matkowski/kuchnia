#pragma once

#include "Panel.hpp"
#include "Series.hpp"

// The open-meteo cache: what it is doing now, and the hourly forecast behind it.
//
// Any field the rest-url query does not ask for arrives absent rather than as an error, so a
// zero here can mean "no data" as easily as "zero degrees"; an empty series is the honest
// signal that a field was not requested, and the scene checks it.
class Weather : public Panel {
	Q_OBJECT
	Q_PROPERTY(double temperature READ temperature NOTIFY currentChanged)
	Q_PROPERTY(double humidity READ humidity NOTIFY currentChanged)
	Q_PROPERTY(int weatherCode READ weatherCode NOTIFY currentChanged)
	Q_PROPERTY(ChartSeries temperatureForecast READ temperatureForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries precipitationForecast READ precipitationForecast NOTIFY forecastChanged)
	Q_PROPERTY(QVariantList daylight READ daylight NOTIFY forecastChanged)

public:
	using Panel::Panel;

	double      temperature() const { return m_temperature; }
	double      humidity() const { return m_humidity; }
	int         weatherCode() const { return m_weatherCode; }
	ChartSeries temperatureForecast() const { return m_temperatureForecast; }
	ChartSeries precipitationForecast() const { return m_precipitationForecast; }
	QVariantList daylight() const { return m_daylight; }

	// GUI thread only.
	void update(const WeatherUpdate& update);

signals:
	void currentChanged();
	void forecastChanged();

private:
	double      m_temperature = 0.0;
	double      m_humidity = 0.0;
	int         m_weatherCode = 0;
	ChartSeries m_temperatureForecast;
	ChartSeries m_precipitationForecast;
	QVariantList m_daylight;
};
