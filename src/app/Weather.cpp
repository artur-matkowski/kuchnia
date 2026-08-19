#include "Weather.hpp"

void Weather::update(const WeatherUpdate& update)
{
	m_temperature = update.temperature;
	m_humidity    = update.humidity;
	m_weatherCode = update.weatherCode;
	emit currentChanged();

	m_temperatureForecast   = ChartSeries::from(update.temperatureForecast);
	m_precipitationForecast = ChartSeries::from(update.precipitationForecast);
	emit forecastChanged();
}
