import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/service/planner/activity_area_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  const areas = ActivityAreaService();
  test(
    'Relaxed stays compact while Moderate and Explorer spread progressively',
    () {
      final candidates = [
        for (var i = 0; i < 10; i++) place('central-$i', 108 + i * 0.0001),
        place('nearby-area', 108.03),
        place('outer-area', 108.08),
      ];
      Set<String> ids(String pace) => generate(candidates, activityLevel: pace)
          .days
          .single
          .places
          .where((p) => !p.place.isDining)
          .map((p) => p.place.id)
          .toSet();
      final relaxed = ids('Relaxed');
      expect(relaxed.every((id) => id.startsWith('osm:central-')), isTrue);
      final moderate = ids('Moderate');
      expect(moderate, contains('osm:nearby-area'));
      expect(moderate, isNot(contains('osm:outer-area')));
      final explorer = ids('Very Active');
      expect(explorer, containsAll(['osm:nearby-area', 'osm:outer-area']));
    },
  );
  test(
    'balanced plan includes another area instead of four central sights',
    () {
      final result = generate([
        for (var i = 0; i < 8; i++) place('central-$i', 108 + i * 0.0001),
        place('other-area', 108.03),
      ]);
      final activities = result.days.single.places
          .where((p) => !p.place.isDining)
          .map((p) => p.place)
          .toList();
      expect(result.validation.isValid, isTrue);
      expect(activities.map((p) => p.id), contains('osm:other-area'));
      expect(areas.areaCount(activities), greaterThanOrEqualTo(2));
    },
  );
  test('unaffordable alternatives do not consume variety or empty the day', () {
    final result = generate([
      for (var i = 0; i < 5; i++) place('central-$i', 108),
      place('unaffordable', 108.03, cost: 100000),
    ]);
    expect(result.validation.isValid, isTrue);
    expect(result.days.single.activityCount, 4);
    expect(
      result.days.single.places.any((p) => p.place.id == 'osm:unaffordable'),
      isFalse,
    );
  });
  test('compact destinations still retain distinct nearby activities', () {
    final result = generate([
      for (var i = 0; i < 5; i++) place('central-$i', 108),
    ]);
    expect(result.validation.isValid, isTrue);
    expect(result.days.single.activityCount, 4);
    expect(result.days.single.places.map((p) => p.place.id).toSet().length, 7);
  });
  test('variety does not force a distant lower-scoring activity', () {
    final result = generate([
      for (var i = 0; i < 5; i++) place('central-$i', 108),
      place('far-away', 109),
    ]);
    expect(
      result.days.single.places.any((p) => p.place.id == 'osm:far-away'),
      isFalse,
    );
  });
  test('failed candidates do not change the chosen areas', () {
    final result = generate([
      place('unaffordable', 108.03, cost: 100000),
      for (var i = 0; i < 8; i++) place('central-$i', 108),
      place('other-area', 108.03),
    ]);
    expect(
      result.days.single.places.any((p) => p.place.id == 'osm:other-area'),
      isTrue,
    );
  });
}

TravelPlace place(
  String id,
  double longitude, {
  String category = 'museum',
  double cost = 5,
}) => TravelPlace.fromMap({
  'id': 'osm:$id',
  'name': id,
  'category': category,
  'tags': [category],
  'latitude': 16,
  'longitude': longitude,
  'estimatedVisitMinutes': 60,
  'estimatedCost': cost,
});

PlannerResult generate(
  List<TravelPlace> activities, {
  String activityLevel = 'Moderate',
}) => TravelPlannerService(placeScoringService: const PlaceScoringService())
    .generatePlan(
      trip: Trip(
        id: 'test',
        ownerId: 'test',
        destination: 'Fixture',
        days: 1,
        budget: 1000,
        status: 'draft',
      ),
      preference: Preference(
        id: 'test',
        ownerId: 'test',
        experienceType: ['History'],
        interests: ['History'],
        activityLevel: activityLevel,
        spendingStyle: 'Normal',
      ),
      candidatePlaces: [
        ...activities,
        for (var i = 0; i < 3; i++)
          place('meal-$i', 108, category: 'restaurant'),
      ],
      centerLatitude: 16,
      centerLongitude: 108,
    );
