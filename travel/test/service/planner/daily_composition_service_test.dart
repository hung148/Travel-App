import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/place_role.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/service/planner/daily_composition_service.dart';
import 'package:travel/service/planner/place_role_classifier.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  const classifier = PlaceRoleClassifier();

  test('classifies specific restaurant types as dining', () {
    expect(
      classifier.classify(_place('ramen', 'ramen_restaurant')),
      PlaceRole.dining,
    );
    expect(classifier.classify(_place('museum', 'museum')), PlaceRole.culture);
    expect(classifier.classify(_place('park', 'park')), PlaceRole.nature);
  });

  test('classifies only actual shopping malls as shopping', () {
    expect(
      classifier.classify(_place('vincom', 'shopping_mall')),
      PlaceRole.shopping,
    );
    expect(classifier.classify(_place('shoes', 'shoe_store')), PlaceRole.other);
    expect(
      classifier.classify(_place('electronics', 'electronics_store')),
      PlaceRole.other,
    );
    expect(
      classifier.classify(_place('department', 'department_store')),
      PlaceRole.other,
    );
  });

  test('allows up to ten dining places in a food-focused day', () {
    const service = DailyCompositionService();
    final arranged = service.arrange(
      routeOrderedPlaces: List.generate(
        11,
        (index) => _scored('food-$index', 'restaurant'),
      ),
      profile: PlannerProfile.explorer,
    );

    expect(arranged, hasLength(10));
  });

  test('places breakfast, lunch, and dinner around activities', () {
    const service = DailyCompositionService();
    final arranged = service.arrange(
      routeOrderedPlaces: [
        _scored('museum', 'museum'),
        _scored('park', 'park'),
        _scored('breakfast', 'cafe'),
        _scored('lunch', 'restaurant'),
        _scored('dinner', 'sushi_restaurant'),
      ],
      profile: PlannerProfile.relaxed,
    );

    expect(arranged.map((item) => item.place.id), [
      'breakfast',
      'museum',
      'lunch',
      'park',
      'dinner',
    ]);
  });

  test('relaxed planner schedules three meals separately from activities', () {
    final planner = TravelPlannerService(
      placeScoringService: PlaceScoringService(),
    );
    final result = planner.generatePlan(
      trip: Trip(
        id: 'trip',
        ownerId: 'user',
        destination: 'Tokyo',
        budget: 10000,
        days: 1,
        status: 'draft',
      ),
      preference: Preference(
        id: 'preference',
        ownerId: 'user',
        experienceType: const ['food'],
        activityLevel: 'Relaxed',
        spendingStyle: 'Normal',
        interests: const ['local food'],
      ),
      candidatePlaces: [
        _place('food-1', 'ramen_restaurant', rating: 5),
        _place('food-2', 'sushi_restaurant', rating: 4.9),
        _place('food-3', 'restaurant', rating: 4.8),
        _place('museum', 'museum', rating: 4.7),
        _place('park', 'park', rating: 4.6),
      ],
      centerLatitude: 0,
      centerLongitude: 0,
    );

    final roles = result.days.single.places
        .map((item) => classifier.classify(item.place))
        .toList();
    expect(roles.where((role) => role == PlaceRole.dining), hasLength(3));
    expect(roles.where((role) => role != PlaceRole.dining), hasLength(2));
    expect(result.validation.isValid, isTrue);
  });
}

ScoredPlace _scored(String id, String category) => ScoredPlace(
  place: _place(id, category),
  totalScore: 80,
  ratingScore: 80,
  reviewScore: 80,
  preferenceScore: 80,
  budgetScore: 80,
  distanceScore: 80,
);

TravelPlace _place(String id, String category, {double rating = 4.5}) {
  return TravelPlace(
    id: id,
    name: id,
    category: category,
    tags: [category],
    rating: rating,
    reviewCount: 1000,
    estimatedCost: 10,
    latitude: 0,
    longitude: 0,
    estimatedVisitMinutes: 90,
  );
}
