import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/weather_service.dart';

class StudentWeather extends StatefulWidget {
  const StudentWeather({super.key});

  @override
  State<StudentWeather> createState() => _StudentWeatherState();
}

class _StudentWeatherState extends State<StudentWeather> {
  WeatherData? _weather;
  List<ForecastDay> _forecast = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);
    // Default Nairobi coordinates — in production, get from Geolocator
    final weather = await WeatherService.getFullWeather(-1.2921, 36.8219);
    final forecast = await WeatherService.getForecast(-1.2921, 36.8219);
    if (mounted) {
      setState(() {
        _weather = weather;
        _forecast = forecast;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
    }

    if (_weather == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('WEATHER UNAVAILABLE', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadWeather, child: const Text('RETRY')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWeather,
      color: const Color(0xFF00F0FF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main weather card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1C29),
                  const Color(0xFF00F0FF).withOpacity(0.08),
                ],
              ),
              border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.1), blurRadius: 20)],
            ),
            child: Column(
              children: [
                Text(_weather!.icon, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  '${_weather!.temp.toStringAsFixed(1)}°C',
                  style: GoogleFonts.orbitron(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [const Shadow(color: Color(0xFF00F0FF), blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _weather!.condition.toUpperCase(),
                  style: GoogleFonts.rajdhani(fontSize: 18, color: const Color(0xFF00F0FF), fontWeight: FontWeight.bold, letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text(
                  _weather!.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              Expanded(child: _buildStatCard('FEELS LIKE', '${_weather!.feelsLike.toStringAsFixed(1)}°C', Icons.thermostat)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('HUMIDITY', '${_weather!.humidity}%', Icons.water_drop)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('WIND', '${_weather!.windSpeed.toStringAsFixed(1)} km/h', Icons.air)),
            ],
          ),
          const SizedBox(height: 24),

          // Advisory
          _buildAdvisoryCard(),
          const SizedBox(height: 24),

          // 5-day forecast
          Text('5-DAY FORECAST', style: GoogleFonts.orbitron(color: const Color(0xFF00F0FF), fontSize: 14)),
          const SizedBox(height: 12),
          ..._forecast.map((day) => _buildForecastRow(day)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00F0FF), size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCard() {
    String advisory;
    IconData icon;
    Color color;

    if (_weather!.temp > 30) {
      advisory = 'High temperatures expected. Stay hydrated and avoid prolonged sun exposure.';
      icon = Icons.wb_sunny;
      color = Colors.orangeAccent;
    } else if (_weather!.temp < 15) {
      advisory = 'Cool weather. Consider wearing a jacket to class today.';
      icon = Icons.ac_unit;
      color = Colors.lightBlueAccent;
    } else if (_weather!.condition.contains('Rain') || _weather!.condition.contains('Drizzle')) {
      advisory = 'Rain expected. Carry an umbrella and plan for indoor activities.';
      icon = Icons.umbrella;
      color = Colors.blueAccent;
    } else if (_weather!.condition.contains('Thunder')) {
      advisory = '⚠️ Thunderstorm warning! Consider staying indoors if possible.';
      icon = Icons.flash_on;
      color = Colors.yellowAccent;
    } else {
      advisory = 'Pleasant weather conditions. Great day for classes!';
      icon = Icons.check_circle_outline;
      color = const Color(0xFF00F0FF);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEATHER ADVISORY', style: GoogleFonts.rajdhani(fontSize: 12, color: color, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(advisory, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastRow(ForecastDay day) {
    final dayName = DateFormat('EEE').format(day.date);
    final isToday = DateFormat('yyyy-MM-dd').format(day.date) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        border: Border.all(color: isToday ? const Color(0xFF00F0FF).withOpacity(0.3) : Colors.white10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              isToday ? 'TODAY' : dayName.toUpperCase(),
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                color: isToday ? const Color(0xFF00F0FF) : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(day.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(day.condition, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ),
          Text(
            '${day.tempMax.toStringAsFixed(0)}°',
            style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            '${day.tempMin.toStringAsFixed(0)}°',
            style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
