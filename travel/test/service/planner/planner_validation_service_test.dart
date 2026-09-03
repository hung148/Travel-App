import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/budget_allocation.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/planner_validation.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/planner_validation_service.dart';

void main() {
  const validator = PlannerValidationService();
  const allocation = BudgetAllocation(
    total: 1000,
    accommodation: 400,
    food: 200,
    transportation: 150,
    activities: 200,
    buffer: 50,
  );

  test('reports every hard itinerary constraint violation', () {
    final duplicate = _scoredPlace('duplicate', cost: 60, minutes: 100);
    final eligible = _scoredPlace('eligible', cost: 10, minutes: 60);
    final result = validator.validate(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: [duplicate, duplicate, duplicate, duplicate],
        ),
        const PlannerDay(dayNumber: 2, places: []),
      ],
      rankedPlaces: [duplicate, eligible],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
    );

    final codes = result.errors.map((issue) => issue.code).toSet();
    expect(codes, contains(PlannerValidationCode.duplicatePlace));
    expect(codes, contains(PlannerValidationCode.dailyCostExceeded));
    expect(codes, contains(PlannerValidationCode.dailyTimeExceeded));
    expect(codes, contains(PlannerValidationCode.dailyPlaceCountExceeded));
    expect(codes, contains(PlannerValidationCode.avoidableEmptyDay));
    expect(codes, contains(PlannerValidationCode.totalActivityCostExceeded));
    expect(result.isValid, isFalse);
  });

  test('treats an unavoidable empty day as a warning', () {
    final result = validator.validate(
      days: const [PlannerDay(dayNumber: 1, places: [])],
      rankedPlaces: const [],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
    );

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
    expect(
      result.warnings.map((issue) => issue.code),
      containsAll([
        PlannerValidationCode.dailyMealMinimumMissing,
        PlannerValidationCode.unavoidableEmptyDay,
      ]),
    );
  });

  test('accepts a valid itinerary without issues', () {
    final place = _scoredPlace('valid', cost: 50, minutes: 120);
    final meals = [
      _scoredPlace('breakfast', cost: 10, minutes: 45, category: 'cafe'),
      _scoredPlace('lunch', cost: 10, minutes: 60, category: 'restaurant'),
      _scoredPlace(
        'dinner',
        cost: 10,
        minutes: 60,
        category: 'sushi_restaurant',
      ),
    ];
    final result = validator.validate(
      days: [
        PlannerDay(dayNumber: 1, places: [...meals, place]),
      ],
      rankedPlaces: [...meals, place],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
    );

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('rejects a relaxed day with too many dining stops', () {
    final result = validator.validate(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: List.generate(
            11,
            (index) => _scoredPlace(
              'meal-${index + 1}',
              cost: 10,
              minutes: 20,
              category: 'restaurant',
            ),
          ),
        ),
      ],
      rankedPlaces: const [],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
    );

    expect(
      result.errors.map((issue) => issue.code),
      contains(PlannerValidationCode.dailyDiningLimitExceeded),
    );
  });

  test('turns planner limits into warnings for explicit user overrides', () {
    final result = validator.validate(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: List.generate(
            11,
            (index) => _scoredPlace(
              'meal-${index + 1}',
              cost: 10,
              minutes: 60,
              category: 'restaurant',
            ),
          ),
        ),
      ],
      rankedPlaces: const [],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
      allowUserOverrides: true,
    );

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
    expect(
      result.warnings.map((issue) => issue.code),
      contains(PlannerValidationCode.dailyDiningLimitExceeded),
    );
  });

  test('keeps required meals valid when the food allocation is too small', () {
    final result = validator.validate(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: [
            _scoredPlace('breakfast', cost: 90, minutes: 45, category: 'cafe'),
            _scoredPlace(
              'lunch',
              cost: 90,
              minutes: 60,
              category: 'restaurant',
            ),
            _scoredPlace(
              'dinner',
              cost: 90,
              minutes: 75,
              category: 'sushi_restaurant',
            ),
          ],
        ),
      ],
      rankedPlaces: const [],
      profile: PlannerProfile.relaxed,
      budgetAllocation: allocation,
    );

    expect(result.isValid, isTrue);
    expect(
      result.warnings.map((issue) => issue.code),
      containsAll([
        PlannerValidationCode.dailyFoodCostExceeded,
        PlannerValidationCode.totalFoodCostExceeded,
      ]),
    );
  });
}

ScoredPlace _scoredPlace(
  String id, {
  required double cost,
  required int minutes,
  String category = 'museum',
}) {
  return ScoredPlace(
    place: TravelPlace(
      id: id,
      name: id,
      category: category,
      tags: [category],
      rating: 4,
      reviewCount: 100,
      estimatedCost: cost,
      latitude: 0,
      longitude: 0,
      estimatedVisitMinutes: minutes,
    ),
    totalScore: 80,
    ratingScore: 80,
    reviewScore: 80,
    preferenceScore: 80,
    budgetScore: 80,
    distanceScore: 80,
  );
}
