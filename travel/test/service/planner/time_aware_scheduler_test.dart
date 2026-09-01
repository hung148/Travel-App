import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  final planner = TravelPlannerService(
    placeScoringService: PlaceScoringService(),
  );

  group('time-aware daily scheduler', () {
    test('never fills a day beyond the strategy time cap', () {
      final result = planner.generatePlan(
        trip: _trip(days: 2),
        preference: _preference('Relaxed'),
        candidatePlaces: List.generate(
          8,
          (index) => _place('place-$index', minutes: 180),
        ),
        centerLatitude: 0,
        centerLongitude: 0,
      );

      expect(result.days, hasLength(2));
      for (final day in result.days) {
        expect(
          day.estimatedVisitMinutes,
          lessThanOrEqualTo(result.profile.targetMinutesPerDay),
        );
        expect(day.places, hasLength(1));
      }
    });

    test(
      'different profiles produce different schedules from the same data',
      () {
        final candidates = List.generate(
          6,
          (index) => _place('place-$index', minutes: 150),
        );

        final relaxed = planner.generatePlan(
          trip: _trip(days: 1),
          preference: _preference('Relaxed'),
          candidatePlaces: candidates,
          centerLatitude: 0,
          centerLongitude: 0,
        );
        final balanced = planner.generatePlan(
          trip: _trip(days: 1),
          preference: _preference('Moderate'),
          candidatePlaces: candidates,
          centerLatitude: 0,
          centerLongitude: 0,
        );
        final explorer = planner.generatePlan(
          trip: _trip(days: 1),
          preference: _preference('Very Active'),
          candidatePlaces: candidates,
          centerLatitude: 0,
          centerLongitude: 0,
        );

        expect(relaxed.days.single.places, hasLength(2));
        expect(balanced.days.single.places, hasLength(2));
        expect(explorer.days.single.places, hasLength(3));
        expect(relaxed.days.single.estimatedVisitMinutes, 300);
        expect(explorer.days.single.estimatedVisitMinutes, 450);
      },
    );

    test(
      'skips an over-limit place and continues looking for one that fits',
      () {
        final result = planner.generatePlan(
          trip: _trip(days: 1),
          preference: _preference('Relaxed'),
          candidatePlaces: [
            _place('too-long', minutes: 360, rating: 5),
            _place('fits', minutes: 120, rating: 4),
          ],
          centerLatitude: 0,
          centerLongitude: 0,
        );

        expect(result.days.single.places.map((item) => item.place.id), [
          'fits',
        ]);
        expect(result.days.single.estimatedVisitMinutes, 120);
      },
    );
  });
}

Trip _trip({required int days}) {
  return Trip(
    id: 'trip',
    ownerId: 'user',
    destination: 'Test City',
    budget: 10000,
    days: days,
    status: 'draft',
  );
}

Preference _preference(String activityLevel) {
  return Preference(
    id: 'preference',
    ownerId: 'user',
    experienceType: const ['museum'],
    activityLevel: activityLevel,
    spendingStyle: 'Normal',
    interests: const ['history'],
  );
}

TravelPlace _place(String id, {required int minutes, double rating = 4.5}) {
  return TravelPlace(
    id: id,
    name: id,
    category: 'museum',
    tags: const ['history'],
    rating: rating,
    reviewCount: 1000,
    estimatedCost: 10,
    latitude: 0,
    longitude: 0,
    estimatedVisitMinutes: minutes,
  );
}
