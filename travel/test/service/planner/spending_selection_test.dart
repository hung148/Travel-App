import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/cost_estimate.dart';
import 'package:travel/models/hotel_stay.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/service/budget_service.dart';
import 'package:travel/service/planner/dining_selection_service.dart';
import 'package:travel/service/planner/hotel_selection_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  const dining = DiningSelectionService();
  final meals = [
    for (var i = 0; i < 3; i++) place('local-$i', 5),
    place('fine', 45, priceLevel: 3),
  ].map(scored).toList();
  test(
    'larger allowance selects premium dinner and small allowance selects local',
    () {
      final small = dining.select(
        candidates: meals,
        days: 1,
        mealsPerDay: 3,
        dailyBudget: 20,
      );
      final large = dining.select(
        candidates: meals,
        days: 1,
        mealsPerDay: 3,
        dailyBudget: 100,
      );
      expect(small.single.last.place.id, startsWith('local'));
      expect(large.single.last.place.id, 'fine');
      expect(
        large.single.fold<double>(
          0,
          (sum, item) => sum + item.place.estimatedCost,
        ),
        lessThanOrEqualTo(100),
      );
    },
  );
  test('dinner leaves enough money for breakfast and lunch', () {
    final result = dining.select(
      candidates: [...meals, scored(place('over-budget', 95))],
      days: 1,
      mealsPerDay: 3,
      dailyBudget: 100,
    );
    expect(
      result.single.map((item) => item.place.id),
      isNot(contains('over-budget')),
    );
    expect(result.single, hasLength(3));
  });
  test('month-long trips can repeat the best available dinner', () {
    final result = dining.select(
      candidates: meals,
      days: 30,
      mealsPerDay: 3,
      dailyBudget: 100,
    );
    expect(result, hasLength(30));
    expect(result.every((day) => day.last.place.id == 'fine'), isTrue);
    expect(
      result.every(
        (day) => day.map((item) => item.place.id).toSet().length == 3,
      ),
      isTrue,
    );
  });
  test(
    'hotel allowance includes all nights and rooms and changes with total budget',
    () {
      final hotels = [
        hotel('local', 40, 4.7),
        hotel('premium', 180, 4.8),
        hotel('unaffordable', 900, 5),
      ];
      final small = const HotelSelectionService().select(
        hotels,
        nights: 2,
        rooms: 2,
        accommodationBudget: 200,
      );
      final large = const HotelSelectionService().select(
        hotels,
        nights: 2,
        rooms: 2,
        accommodationBudget: 800,
      );
      expect(small!.id, 'local');
      expect(small.totalCost, 160);
      expect(large!.id, 'premium');
      expect(large.totalCost, 720);
    },
  );
  test('hotel is reserved inside the total rather than added on top', () {
    final allocation = const BudgetService().allocateForTrip(
      totalBudget: 1000,
      accommodationCost: 600,
    );
    expect(allocation.accommodation, 600);
    expect(allocation.allocatedTotal, closeTo(1000, 0.001));
    expect(
      allocation.food +
          allocation.activities +
          allocation.transportation +
          allocation.buffer,
      closeTo(400, 0.001),
    );
    expect(
      () => const BudgetService().allocateForTrip(
        totalBudget: 100,
        accommodationCost: 200,
      ),
      throwsArgumentError,
    );
  });
  final planner = TravelPlannerService(
    placeScoringService: const PlaceScoringService(),
  );
  plan(String style, {int travelers = 1}) => planner.generatePlan(
    trip: Trip(
      id: 'trip',
      ownerId: 'u',
      destination: 'City',
      budget: 1000,
      days: 3,
      status: 'draft',
      travelers: travelers,
    ),
    accommodationCost: 300,
    preference: Preference(
      id: 'p',
      ownerId: 'u',
      experienceType: const ['Nature'],
      activityLevel: 'Relaxed',
      spendingStyle: style,
      interests: const ['Nature'],
    ),
    candidatePlaces: [
      ...meals.map((item) => item.place),
      for (var i = 0; i < 12; i++) place('park-$i', 0, dining: false),
    ],
    centerLatitude: 0,
    centerLongitude: 0,
  );
  test('old saved spending preferences cannot change the plan', () {
    final budget = plan('Budget');
    final luxury = plan('Luxury');
    expect(budget.validation.isValid, isTrue);
    expect(luxury.validation.isValid, isTrue);
    expect(
      luxury.days.expand((day) => day.places).map((item) => item.place.id),
      budget.days.expand((day) => day.places).map((item) => item.place.id),
    );
  });
  test('food allowance covers every traveler within total budget', () {
    final result = plan('Normal', travelers: 4);
    expect(result.validation.isValid, isTrue);
    expect(result.budgetAllocation.accommodation, 300);
    expect(
      result.days.fold<double>(0, (sum, day) => sum + day.estimatedFoodCost),
      lessThanOrEqualTo(result.budgetAllocation.food + 0.001),
    );
  });
}

TravelPlace place(
  String id,
  double price, {
  bool dining = true,
  bool luxuryMatch = false,
  int? priceLevel,
}) => TravelPlace(
  id: id,
  name: id,
  category: dining ? 'restaurant' : 'park',
  tags: [dining ? 'restaurant' : 'park'],
  rating: 4.6,
  reviewCount: 500,
  luxuryDiningSearchMatch: luxuryMatch,
  cost: CostEstimate(
    low: price,
    high: price,
    currencyCode: 'USD',
    source: CostSource.userProvided,
    priceLevel: priceLevel,
  ),
  latitude: 0,
  longitude: 0,
  estimatedVisitMinutes: 45,
);

ScoredPlace scored(TravelPlace place) => ScoredPlace(
  place: place,
  totalScore: 80,
  ratingScore: 80,
  reviewScore: 80,
  preferenceScore: 80,
  budgetScore: 80,
  distanceScore: 80,
);

HotelStay hotel(String id, double rate, double rating) => HotelStay(
  id: id,
  name: id,
  address: 'City',
  latitude: 0,
  longitude: 0,
  rating: rating,
  nightlyRate: rate,
  nights: 1,
  rooms: 1,
);
