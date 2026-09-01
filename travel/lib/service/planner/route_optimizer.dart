import 'dart:math';

import '../../models/score_place.dart';

class RouteOptimizer {
  const RouteOptimizer();

  List<ScoredPlace> optimize({
    required List<ScoredPlace> places,
    required double startLatitude,
    required double startLongitude,
  }) {
    if (places.length < 2) return List.of(places);

    final remaining = List<ScoredPlace>.of(places);
    final ordered = <ScoredPlace>[];
    var currentLatitude = startLatitude;
    var currentLongitude = startLongitude;

    while (remaining.isNotEmpty) {
      var nearestIndex = 0;
      var nearestDistance = _distanceKm(
        startLatitude: currentLatitude,
        startLongitude: currentLongitude,
        endLatitude: remaining.first.place.latitude,
        endLongitude: remaining.first.place.longitude,
      );

      for (var index = 1; index < remaining.length; index++) {
        final candidate = remaining[index];
        final candidateDistance = _distanceKm(
          startLatitude: currentLatitude,
          startLongitude: currentLongitude,
          endLatitude: candidate.place.latitude,
          endLongitude: candidate.place.longitude,
        );

        if (candidateDistance < nearestDistance) {
          nearestIndex = index;
          nearestDistance = candidateDistance;
        }
      }

      final nearest = remaining.removeAt(nearestIndex);
      ordered.add(nearest);
      currentLatitude = nearest.place.latitude;
      currentLongitude = nearest.place.longitude;
    }

    return ordered;
  }

  double _distanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = _radians(endLatitude - startLatitude);
    final longitudeDelta = _radians(endLongitude - startLongitude);

    final a =
        pow(sin(latitudeDelta / 2), 2) +
        cos(_radians(startLatitude)) *
            cos(_radians(endLatitude)) *
            pow(sin(longitudeDelta / 2), 2);
    final arc = 2 * atan2(sqrt(a.toDouble()), sqrt((1 - a).toDouble()));

    return earthRadiusKm * arc;
  }

  double _radians(double degrees) => degrees * pi / 180;
}
