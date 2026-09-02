import '../../../service/map_service.dart';
import 'travel_leg_draft.dart';

class TravelTimeEstimator {
  const TravelTimeEstimator();

  /// Conservative baseline used to estimate airborne time only. This does not
  /// include check-in, boarding, taxiing, connections, or delays.
  static const double assumedFlightCruiseSpeedKmh = 750;

  Future<TravelEstimate> estimate({
    required MapService mapService,
    required String origin,
    required String destination,
  }) async {
    final points = await Future.wait([
      mapService.geocodeAddress(origin),
      mapService.geocodeAddress(destination),
    ]);
    final distance = mapService.calculateDistanceKm(
      startLat: points[0].latitude,
      startLng: points[0].longitude,
      endLat: points[1].latitude,
      endLng: points[1].longitude,
    );
    final mode = distance <= 650 ? TravelMode.driving : TravelMode.flight;
    final hours = mode == TravelMode.driving
        ? (distance / 70) * 1.15
        : distance / assumedFlightCruiseSpeedKmh;
    return TravelEstimate(
      mode: mode,
      distanceKm: distance,
      durationHours: hours,
      originLatitude: points[0].latitude,
      originLongitude: points[0].longitude,
      destinationLatitude: points[1].latitude,
      destinationLongitude: points[1].longitude,
    );
  }
}
