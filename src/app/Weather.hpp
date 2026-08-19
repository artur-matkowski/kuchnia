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
	Q_PROPERTY(double windSpeed READ windSpeed NOTIFY currentChanged)
	Q_PROPERTY(double windDirection READ windDirection NOTIFY currentChanged)
	Q_PROPERTY(double cloudCover READ cloudCover NOTIFY currentChanged)
	Q_PROPERTY(double rain READ rain NOTIFY currentChanged)
	Q_PROPERTY(double snowfall READ snowfall NOTIFY currentChanged)
	Q_PROPERTY(ChartSeries temperatureForecast READ temperatureForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries precipitationForecast READ precipitationForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries precipitationAmountForecast READ precipitationAmountForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudCoverForecast READ cloudCoverForecast NOTIFY forecastChanged)
	Q_PROPERTY(QVariantList daylight READ daylight NOTIFY forecastChanged)

public:
	using Panel::Panel;

	double      temperature() const { return m_temperature; }
	double      humidity() const { return m_humidity; }
	int         weatherCode() const { return m_weatherCode; }
	double      windSpeed() const { return m_windSpeed; }
	// Meteorological: the direction the wind blows FROM. An arrow pointing that way is
	// pointing at where the weather is coming from, which is the way a weather vane reads and
	// the opposite of the way an arrow normally reads.
	double      windDirection() const { return m_windDirection; }
	double      cloudCover() const { return m_cloudCover; }
	double      rain() const { return m_rain; }
	double      snowfall() const { return m_snowfall; }
	ChartSeries temperatureForecast() const { return m_temperatureForecast; }
	// Percent probability. Not the same series as the one below, and not in the same unit.
	ChartSeries precipitationForecast() const { return m_precipitationForecast; }
	// Millimetres per hour, rain and snow together.
	ChartSeries precipitationAmountForecast() const { return m_precipitationAmountForecast; }
	ChartSeries cloudCoverForecast() const { return m_cloudCoverForecast; }
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
	double      m_windSpeed = 0.0;
	double      m_windDirection = 0.0;
	double      m_cloudCover = 0.0;
	double      m_rain = 0.0;
	double      m_snowfall = 0.0;
	ChartSeries m_temperatureForecast;
	ChartSeries m_precipitationForecast;
	ChartSeries m_precipitationAmountForecast;
	ChartSeries m_cloudCoverForecast;
	QVariantList m_daylight;
};
