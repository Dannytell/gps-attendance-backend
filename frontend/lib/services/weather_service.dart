import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String condition;
  final String description;
  final String icon;
  final String cityName;

  WeatherData({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.description,
    required this.icon,
    required this.cityName,
  });
}

class ForecastDay {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String icon;

  ForecastDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.icon,
  });
}

class WeatherService {
  // Using Open-Meteo API - completely free, no API key needed
  static const String _baseUrl = 'https://api.open-meteo.com/v1';

  static Future<WeatherData?> getFullWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code'
        '&timezone=auto'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final weatherCode = current['weather_code'] as int;
        final condition = _getConditionFromCode(weatherCode);

        return WeatherData(
          temp: (current['temperature_2m'] as num).toDouble(),
          feelsLike: (current['apparent_temperature'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toInt(),
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          condition: condition['label']!,
          description: condition['description']!,
          icon: condition['icon']!,
          cityName: 'Current Location',
        );
      }
    } catch (e) {
      debugPrint('Weather error: $e');
    }
    return null;
  }

  static Future<List<ForecastDay>> getForecast(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?latitude=$lat&longitude=$lon'
        '&daily=temperature_2m_max,temperature_2m_min,weather_code'
        '&timezone=auto&forecast_days=5'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];
        final List<ForecastDay> forecast = [];

        for (int i = 0; i < (daily['time'] as List).length; i++) {
          final code = daily['weather_code'][i] as int;
          final condition = _getConditionFromCode(code);
          forecast.add(ForecastDay(
            date: DateTime.parse(daily['time'][i]),
            tempMin: (daily['temperature_2m_min'][i] as num).toDouble(),
            tempMax: (daily['temperature_2m_max'][i] as num).toDouble(),
            condition: condition['label']!,
            icon: condition['icon']!,
          ));
        }
        return forecast;
      }
    } catch (e) {
      debugPrint('Forecast error: $e');
    }
    return [];
  }

  // For backward compat with the old simple call
  static Future<String> getTemperature() async {
    try {
      // Default to Nairobi coordinates as fallback
      final weather = await getFullWeather(-1.2921, 36.8219);
      if (weather != null) {
        return '${weather.temp.toStringAsFixed(1)}°C';
      }
    } catch (e) {
      debugPrint('Temp error: $e');
    }
    return 'N/A';
  }

  static Map<String, String> _getConditionFromCode(int code) {
    // WMO Weather interpretation codes
    if (code == 0) return {'label': 'Clear Sky', 'description': 'Clear sky with sunshine', 'icon': '☀️'};
    if (code == 1) return {'label': 'Mainly Clear', 'description': 'Mainly clear skies', 'icon': '🌤️'};
    if (code == 2) return {'label': 'Partly Cloudy', 'description': 'Partly cloudy skies', 'icon': '⛅'};
    if (code == 3) return {'label': 'Overcast', 'description': 'Overcast cloud cover', 'icon': '☁️'};
    if (code == 45 || code == 48) return {'label': 'Foggy', 'description': 'Fog or rime fog', 'icon': '🌫️'};
    if (code == 51 || code == 53 || code == 55) return {'label': 'Drizzle', 'description': 'Light drizzle', 'icon': '🌦️'};
    if (code == 61 || code == 63 || code == 65) return {'label': 'Rain', 'description': 'Rainy conditions', 'icon': '🌧️'};
    if (code == 66 || code == 67) return {'label': 'Freezing Rain', 'description': 'Freezing rain', 'icon': '🌨️'};
    if (code == 71 || code == 73 || code == 75) return {'label': 'Snowfall', 'description': 'Snowfall expected', 'icon': '❄️'};
    if (code == 77) return {'label': 'Snow Grains', 'description': 'Snow grains', 'icon': '🌨️'};
    if (code == 80 || code == 81 || code == 82) return {'label': 'Rain Showers', 'description': 'Rain showers', 'icon': '🌧️'};
    if (code == 85 || code == 86) return {'label': 'Snow Showers', 'description': 'Snow showers', 'icon': '🌨️'};
    if (code == 95) return {'label': 'Thunderstorm', 'description': 'Thunderstorm activity', 'icon': '⛈️'};
    if (code == 96 || code == 99) return {'label': 'Hailstorm', 'description': 'Thunderstorm with hail', 'icon': '⛈️'};
    return {'label': 'Unknown', 'description': 'Unknown conditions', 'icon': '🌡️'};
  }
}
