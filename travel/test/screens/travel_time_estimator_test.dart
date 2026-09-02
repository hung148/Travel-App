import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/views/plan_trip/models/travel_leg_draft.dart';
import 'package:travel/views/plan_trip/models/travel_time_estimator.dart';

class _FakeMapService extends MapService {
  _FakeMapService(this.points) : super(apiKey: 'test');
  final Map<String, Coordinates> points;

  @override
  Future<Coordinates> geocodeAddress(String address) async => points[address]!;
}

void main() {
  test('long-distance destinations use an editable flight estimate', () async {
    final service = _FakeMapService({
      'Los Angeles': Coordinates(latitude: 34.0522, longitude: -118.2437),
      'New York': Coordinates(latitude: 40.7128, longitude: -74.0060),
    });
    final estimate = await const TravelTimeEstimator().estimate(
      mapService: service,
      origin: 'Los Angeles',
      destination: 'New York',
    );

    expect(estimate.mode, TravelMode.flight);
    expect(estimate.distanceKm, greaterThan(3000));
    expect(
      estimate.durationHours,
      closeTo(
        estimate.distanceKm / TravelTimeEstimator.assumedFlightCruiseSpeedKmh,
        0.001,
      ),
    );

    final leg = TravelLegDraft(
      fromDestinationId: 'la',
      toDestinationId: 'nyc',
      estimate: estimate,
    );
    leg.overrideDurationHours = 49;
    expect(leg.transitDays, 3);
    expect(leg.isOverridden, isTrue);
  });
}
