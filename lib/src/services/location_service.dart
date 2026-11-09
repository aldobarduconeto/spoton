import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Status de permissão/disponibilidade de localização.
enum LocationStatus { initial, loading, granted, denied, disabled }

/// Serviço de localização do dispositivo.
/// Gerencia permissões, posição atual e cálculo de distâncias.
class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  LocationStatus _status = LocationStatus.initial;
  String _currentCity = '';

  Position? get currentPosition => _currentPosition;
  LocationStatus get status => _status;
  String get currentCity => _currentCity;

  bool get hasLocation => _currentPosition != null;

  /// Pede permissão e obtém a posição atual do usuário.
  Future<void> requestLocation() async {
    _status = LocationStatus.loading;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationStatus.disabled;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = LocationStatus.denied;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = LocationStatus.denied;
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _currentPosition = position;
      _status = LocationStatus.granted;
      notifyListeners();
    } catch (e) {
      debugPrint('LocationService error: $e');
      _status = LocationStatus.denied;
      notifyListeners();
    }
  }

  /// Calcula a distância em km entre a posição atual e um ponto (lat, lng).
  /// Usa a fórmula de Haversine.
  double? distanceTo(double lat, double lng) {
    if (_currentPosition == null) return null;
    return _haversineKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  /// Retorna uma string formatada de distância, ex: "1,2 km" ou "340 m".
  String formattedDistanceTo(double lat, double lng) {
    final km = distanceTo(lat, lng);
    if (km == null) return '';
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Filtra e ordena uma lista de objetos com coordenadas pelo raio informado (km).
  /// Retorna lista de pares (item, distânciaKm) em ordem crescente de distância.
  List<({T item, double distanceKm})> filterByRadius<T>({
    required List<T> items,
    required double Function(T) latitude,
    required double Function(T) longitude,
    required double radiusKm,
  }) {
    if (_currentPosition == null) {
      // Sem localização: retorna tudo sem distância calculada
      return items.map((i) => (item: i, distanceKm: 0.0)).toList();
    }

    final results = <({T item, double distanceKm})>[];
    for (final item in items) {
      final d = _haversineKm(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latitude(item),
        longitude(item),
      );
      if (d <= radiusKm) {
        results.add((item: item, distanceKm: d));
      }
    }
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  /// Fórmula de Haversine: distância em km entre dois pontos geográficos.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // raio da Terra em km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
