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

	m_temperatureForecast         = ChartSeries::from(update.temperatureForecast);
	m_precipitationForecast       = ChartSeries::from(update.precipitationForecast);
	m_precipitationAmountForecast = ChartSeries::from(update.precipitationAmountForecast);
	m_cloudCoverForecast          = ChartSeries::from(update.cloudCoverForecast);
	m_daylight                    = DaylightBand::listFrom(update.daylight);
	emit forecastChanged();
}
