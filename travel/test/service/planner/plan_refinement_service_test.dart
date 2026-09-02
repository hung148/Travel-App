import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/budget_allocation.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/planner_validation.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/plan_refinement_service.dart';

void main() {
  const service = PlanRefinementService();

  test('makes only the requested day more relaxing', () {
    final plan = _plan(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: [_place('a'), _place('b'), _place('c'), _place('d')],
        ),
        PlannerDay(
          dayNumber: 2,
          places: [_place('e'), _place('f'), _place('g'), _place('h')],
        ),
      ],
    );

    final result = service.refine(
      currentPlan: plan,
      instruction: 'make day 2 more relaxing',
    );

    expect(result.changed, isTrue);
    expect(result.plan.validation.isValid, isTrue);
    expect(result.plan.days.first.places, hasLength(4));
    expect(result.plan.days.last.places, hasLength(3));
  });

  test('removes museums and validates the changed plan', () {
    final museum = _place('museum', category: 'museum');
    final park = _place('park', category: 'park');
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [museum, park]),
      ],
      ranked: [museum, park],
    );

    final result = service.refine(
      currentPlan: plan,
      instruction: 'remove museums',
    );

    expect(result.changed, isTrue);
    expect(result.plan.validation.isValid, isTrue);
    expect(result.plan.days.single.places.map((item) => item.place.id), [
      'park',
    ]);
  });

  test('adds food only when all deterministic limits allow it', () {
    final museum = _place('museum', category: 'museum');
    final lunch = _place('lunch', category: 'restaurant');
    final dinner = _place('dinner', category: 'sushi_restaurant');
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [museum, lunch]),
      ],
      ranked: [museum, lunch, dinner],
    );

    final result = service.refine(
      currentPlan: plan,
      instruction: 'add more food places',
    );

    expect(result.changed, isTrue);
    expect(result.plan.validation.isValid, isTrue);
    expect(result.plan.days.single.places, hasLength(3));
    expect(
      result.plan.days.single.places.map((item) => item.place.id),
      contains('dinner'),
    );
  });

  test('explicit more-food request can override the normal dining cap', () {
    final museum = _place('museum', category: 'museum');
    final lunch = _place('lunch', category: 'restaurant');
    final dinner = _place('dinner', category: 'sushi_restaurant');
    final extra = _place('extra', category: 'ramen_restaurant');
    final breakfast = _place('breakfast', category: 'cafe');
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [museum, breakfast, lunch, dinner]),
      ],
      ranked: [museum, breakfast, lunch, dinner, extra],
    );

    final result = service.refine(
      currentPlan: plan,
      instruction: 'add more food',
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places, hasLength(5));
    expect(result.plan.validation.isValid, isTrue);
    expect(
      result.plan.validation.warnings.map((issue) => issue.code),
      contains(PlannerValidationCode.dailyDiningLimitExceeded),
    );
  });
}

PlannerResult _plan({
  required List<PlannerDay> days,
  List<ScoredPlace>? ranked,
}) {
  return PlannerResult(
    budgetAllocation: const BudgetAllocation(
      total: 2000,
      accommodation: 700,
      food: 440,
      transportation: 300,
      activities: 360,
      buffer: 200,
    ),
    validation: const PlannerValidationResult(issues: []),
    profile: PlannerProfile.balanced,
    rankedPlaces: ranked ?? days.expand((day) => day.places).toList(),
    days: days,
  );
}

ScoredPlace _place(String id, {String category = 'park'}) {
  return ScoredPlace(
    place: TravelPlace(
      id: id,
      name: id,
      category: category,
      tags: [category],
      rating: 4.5,
      reviewCount: 1000,
      estimatedCost: 10,
      latitude: 0,
      longitude: 0,
      estimatedVisitMinutes: 90,
    ),
    totalScore: 80,
    ratingScore: 80,
    reviewScore: 80,
    preferenceScore: 80,
    budgetScore: 80,
    distanceScore: 80,
  );
}
