#pragma once

#include "Panel.hpp"
#include "Series.hpp"

// The open-meteo cache: what it is doing now, and the hourly forecast behind it.
//
// Any field the query in Rest.cpp does not ask for arrives absent rather than as an error, so
// a zero here can mean "no data" as easily as "zero degrees"; an empty series is the honest
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
	Q_PROPERTY(ChartSeries rainForecast READ rainForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries snowForecast READ snowForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries humidityForecast READ humidityForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudCoverLowForecast READ cloudCoverLowForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudCoverMidForecast READ cloudCoverMidForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudCoverHighForecast READ cloudCoverHighForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries visibilityForecast READ visibilityForecast NOTIFY forecastChanged)
	Q_PROPERTY(QVariantList cloudBaseForecast READ cloudBaseForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudTopForecast READ cloudTopForecast NOTIFY forecastChanged)
	Q_PROPERTY(ChartSeries cloudProfileHours READ cloudProfileHours NOTIFY forecastChanged)
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
	ChartSeries rainForecast() const { return m_rainForecast; }
	ChartSeries snowForecast() const { return m_snowForecast; }
	ChartSeries humidityForecast() const { return m_humidityForecast; }
	ChartSeries cloudCoverLowForecast() const { return m_cloudCoverLowForecast; }
	ChartSeries cloudCoverMidForecast() const { return m_cloudCoverMidForecast; }
	ChartSeries cloudCoverHighForecast() const { return m_cloudCoverHighForecast; }
	ChartSeries visibilityForecast() const { return m_visibilityForecast; }
	// One ChartSeries per coverage threshold, laxest first; WeatherUpdate says what a point is.
	QVariantList cloudBaseForecast() const { return m_cloudBaseForecast; }
	ChartSeries cloudTopForecast() const { return m_cloudTopForecast; }
	ChartSeries cloudProfileHours() const { return m_cloudProfileHours; }
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
	ChartSeries m_rainForecast;
	ChartSeries m_snowForecast;
	ChartSeries m_humidityForecast;
	ChartSeries m_cloudCoverLowForecast;
	ChartSeries m_cloudCoverMidForecast;
	ChartSeries m_cloudCoverHighForecast;
	ChartSeries m_visibilityForecast;
	QVariantList m_cloudBaseForecast;
	ChartSeries m_cloudTopForecast;
	ChartSeries m_cloudProfileHours;
	QVariantList m_daylight;
};
