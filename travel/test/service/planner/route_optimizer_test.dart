import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/route_optimizer.dart';

void main() {
  const optimizer = RouteOptimizer();

  test('orders stops by nearest neighbor from the supplied center', () {
    final optimized = optimizer.optimize(
      places: [
        _scoredPlace('east-far', latitude: 0, longitude: 0.04),
        _scoredPlace('north-near', latitude: 0.01, longitude: 0),
        _scoredPlace('north-next', latitude: 0.02, longitude: 0),
      ],
      startLatitude: 0,
      startLongitude: 0,
    );

    expect(optimized.map((item) => item.place.id), [
      'north-near',
      'north-next',
      'east-far',
    ]);
  });

  test('does not mutate the original ranked list', () {
    final original = [
      _scoredPlace('far', latitude: 0, longitude: 0.03),
      _scoredPlace('near', latitude: 0, longitude: 0.01),
    ];

    final optimized = optimizer.optimize(
      places: original,
      startLatitude: 0,
      startLongitude: 0,
    );

    expect(original.map((item) => item.place.id), ['far', 'near']);
    expect(optimized.map((item) => item.place.id), ['near', 'far']);
  });
}

ScoredPlace _scoredPlace(
  String id, {
  required double latitude,
  required double longitude,
}) {
  final place = TravelPlace(
    id: id,
    name: id,
    category: 'attraction',
    tags: const [],
    rating: 4,
    reviewCount: 100,
    estimatedCost: 10,
    latitude: latitude,
    longitude: longitude,
    estimatedVisitMinutes: 60,
  );

  return ScoredPlace(
    place: place,
    totalScore: 80,
    ratingScore: 80,
    reviewScore: 80,
    preferenceScore: 80,
    budgetScore: 80,
    distanceScore: 80,
  );
}
