import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Garden state driven by real-world weather.
enum WeatherGameState {
  sunny,   // Clear / few clouds  → bright scene, butterflies active
  cloudy,  // Overcast / mist     → dimmed sky, calm atmosphere
  rainy,   // Rain / drizzle      → plants auto-watered, rain particles
  stormy,  // Thunderstorm        → shelter mode, butterflies hidden
  night,   // After local sunset  → firefly mode, ambient glow
}

/// Parsed result returned by [WeatherService.fetchGameWeather].
class WeatherData {
  final double tempCelsius;
  final int humidityPercent;
  final String rawCondition;
  final WeatherGameState gameState;

  const WeatherData({
    required this.tempCelsius,
    required this.humidityPercent,
    required this.rawCondition,
    required this.gameState,
  });

  /// Passive hydration bonus this weather adds per game tick (0 – 5).
  double get passiveHydration {
    switch (gameState) {
      case WeatherGameState.rainy:
        return 5.0;
      case WeatherGameState.stormy:
        return 3.0;
      case WeatherGameState.cloudy:
        return 1.0;
      default:
        return 0.0;
    }
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Fetches real-world weather via OpenWeatherMap and converts it to a
/// [WeatherGameState] for the Tiny Breathe garden.
///
/// Replace [_apiKey] with a valid OWM key.  Returns a sunny fallback on error.
class WeatherService {
  static const String _apiKey = 'YOUR_OWM_API_KEY';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  Future<WeatherData> fetchGameWeather() async {
    try {
      final pos = await _resolvePosition();
      final json = await _fetchFromApi(pos.latitude, pos.longitude);
      return _parseResponse(json);
    } catch (e) {
      debugPrint('[WeatherService] $e — using fallback (sunny)');
      return const WeatherData(
        tempCelsius: 22,
        humidityPercent: 55,
        rawCondition: 'Clear',
        gameState: WeatherGameState.sunny,
      );
    }
  }

  Future<Position> _resolvePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services are disabled.');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }

  Future<Map<String, dynamic>> _fetchFromApi(double lat, double lon) async {
    final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('OWM ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  WeatherData _parseResponse(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List<dynamic>;
    final conditionId = weatherList.first['id'] as int;
    final mainLabel = weatherList.first['main'] as String;
    final temp = (json['main']['temp'] as num).toDouble();
    final humidity = json['main']['humidity'] as int;

    final sunrise = json['sys']['sunrise'] as int;
    final sunset = json['sys']['sunset'] as int;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final isNight = nowEpoch < sunrise || nowEpoch > sunset;

    return WeatherData(
      tempCelsius: temp,
      humidityPercent: humidity,
      rawCondition: mainLabel,
      gameState: _mapToGameState(conditionId, isNight),
    );
  }

  /// Maps OWM condition codes: https://openweathermap.org/weather-conditions
  WeatherGameState _mapToGameState(int id, bool isNight) {
    if (isNight) return WeatherGameState.night;
    if (id >= 200 && id < 300) return WeatherGameState.stormy;
    if (id >= 300 && id < 600) return WeatherGameState.rainy;
    if (id >= 600 && id < 800) return WeatherGameState.cloudy;
    if (id == 800) return WeatherGameState.sunny;
    if (id > 800) return WeatherGameState.cloudy;
    return WeatherGameState.sunny;
  }
}
