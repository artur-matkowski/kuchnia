#include "Weather.hpp"

void Weather::update(const WeatherUpdate& update)
{
	m_temperature   = update.temperature;
	m_humidity      = update.humidity;
	m_weatherCode   = update.weatherCode;
	m_windSpeed     = update.windSpeed;
	m_windDirection = update.windDirection;
	m_cloudCover    = update.cloudCover;
	m_rain          = update.rain;
	m_snowfall      = update.snowfall;
	emit currentChanged();

	m_temperatureForecast    = ChartSeries::from(update.temperatureForecast);
	m_rainForecast           = ChartSeries::from(update.rainForecast);
	m_snowForecast           = ChartSeries::from(update.snowForecast);
	m_humidityForecast       = ChartSeries::from(update.humidityForecast);
	m_cloudCoverLowForecast  = ChartSeries::from(update.cloudCoverLowForecast);
	m_cloudCoverMidForecast  = ChartSeries::from(update.cloudCoverMidForecast);
	m_cloudCoverHighForecast = ChartSeries::from(update.cloudCoverHighForecast);
	m_visibilityForecast     = ChartSeries::from(update.visibilityForecast);
	m_cloudBaseForecast      = ChartSeries::listFrom(update.cloudBaseForecast);
	m_cloudTopForecast       = ChartSeries::from(update.cloudTopForecast);
	m_cloudProfileHours      = ChartSeries::from(update.cloudProfileHours);
	m_daylight               = DaylightBand::listFrom(update.daylight);
	emit forecastChanged();
}
