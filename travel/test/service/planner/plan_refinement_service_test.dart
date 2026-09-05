import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/budget_allocation.dart';
import 'package:travel/models/cost_estimate.dart';
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

  test('relaxing a day preserves meals before optional activities', () {
    final breakfast = _place('breakfast', category: 'cafe');
    final lunch = _place('lunch', category: 'restaurant');
    final dinner = _place('dinner', category: 'sushi_restaurant');
    final plan = _plan(
      days: [
        PlannerDay(
          dayNumber: 1,
          places: [
            breakfast,
            _place('park-low', score: 50),
            lunch,
            _place('museum-medium', category: 'museum', score: 60),
            dinner,
            _place('park-high', score: 70),
            _place('garden', category: 'garden', score: 75),
            _place('landmark', category: 'landmark', score: 72),
          ],
        ),
      ],
    );

    final result = service.refine(
      currentPlan: plan,
      instruction: 'make day 1 more relaxing',
    );

    expect(result.changed, isTrue);
    expect(
      result.plan.days.single.places.map((item) => item.place.id),
      containsAll(['breakfast', 'lunch', 'dinner']),
    );
    expect(result.plan.days.single.activityCount, 3);
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

  test('explicit more-food request stays below the expanded dining cap', () {
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
      isNot(contains(PlannerValidationCode.dailyDiningLimitExceeded)),
    );
  });

  test('adds exactly one requested meal to only the requested day', () {
    final activity1 = _place('activity-1');
    final activity2 = _place('activity-2');
    final cafe = _place('new-cafe', category: 'cafe');
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [activity1]),
        PlannerDay(dayNumber: 2, places: [activity2]),
      ],
      ranked: [activity1, activity2, cafe],
    );

    final result = service.addFood(plan, dayNumber: 1, mealType: 'breakfast');

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places, hasLength(2));
    expect(result.plan.days.first.places.first.place.id, 'new-cafe');
    expect(result.plan.days.last.places, hasLength(1));
  });

  test('removes one specifically named stop', () {
    final palace = _place('palace');
    final park = _place('park');
    final result = service.removeStop(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [palace, park]),
        ],
      ),
      'palace',
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places.map((item) => item.place.id), [
      'park',
    ]);
  });

  test('moves one specifically named stop to another day', () {
    final palace = _place('palace');
    final park = _place('park');
    final result = service.moveStop(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [palace]),
          PlannerDay(dayNumber: 2, places: [park]),
        ],
      ),
      'palace',
      2,
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places, isEmpty);
    expect(result.plan.days.last.places.map((item) => item.place.id), [
      'park',
      'palace',
    ]);
  });

  test('moves any named stop to any existing later day', () {
    final breakfast = _place('breakfast', category: 'cafe');
    final result = service.moveStop(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [breakfast]),
          const PlannerDay(dayNumber: 2, places: []),
          const PlannerDay(dayNumber: 3, places: []),
          const PlannerDay(dayNumber: 4, places: []),
        ],
      ),
      'breakfast',
      4,
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places, isEmpty);
    expect(result.plan.days.last.places.single.place.id, 'breakfast');
  });

  test('does not move a stop to a day outside the itinerary', () {
    final palace = _place('palace');
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [palace]),
      ],
    );
    final result = service.moveStop(plan, 'palace', 9);

    expect(result.changed, isFalse);
    expect(result.plan, same(plan));
    expect(result.message, contains('Day 9 does not exist'));
  });

  test('removes multiple numbered stops from only the requested day', () {
    final result = service.removeNumberedStops(
      _plan(
        days: [
          PlannerDay(
            dayNumber: 1,
            places: [
              _place('one'),
              _place('two'),
              _place('three'),
              _place('four'),
            ],
          ),
          PlannerDay(dayNumber: 2, places: [_place('other-day')]),
        ],
      ),
      1,
      [3, 4],
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places.map((item) => item.place.id), [
      'one',
      'two',
    ]);
    expect(result.plan.days.last.places.single.place.id, 'other-day');
  });

  test('replaces a named stop with the best unused matching alternative', () {
    final palace = _place('palace', score: 70);
    final museum = _place('museum', category: 'museum', score: 95);
    final park = _place('park', category: 'park', score: 90);
    final result = service.replaceStop(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [palace]),
        ],
        ranked: [palace, museum, park],
      ),
      'palace',
      replacementPreference: 'park',
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places.single.place.id, 'park');
  });

  test('replaces a stop using the requested smarter ranking criterion', () {
    final old = _place('old');
    final highlyRated = _place('high-rating', rating: 4.9, cost: 50, score: 70);
    final cheap = _place('cheap', rating: 4.0, cost: 2, score: 60);
    final plan = _plan(
      days: [
        PlannerDay(dayNumber: 1, places: [old]),
      ],
      ranked: [old, highlyRated, cheap],
    );

    final cheaperResult = service.replaceStop(
      plan,
      'old',
      replacementCriterion: 'cheaper',
    );
    final ratedResult = service.replaceStop(
      plan,
      'old',
      replacementCriterion: 'higher_rated',
    );

    expect(cheaperResult.plan.days.single.places.single.place.id, 'cheap');
    expect(ratedResult.plan.days.single.places.single.place.id, 'high-rating');
  });

  test('closer replacement uses live route duration when available', () async {
    final anchor = _place('hotel-anchor', latitude: 1);
    final old = _place('old-breakfast', category: 'restaurant', latitude: 2);
    final scoreFavorite = _place(
      'score-favorite',
      category: 'restaurant',
      score: 95,
      latitude: 10,
    );
    final routeFavorite = _place(
      'route-favorite',
      category: 'restaurant',
      score: 60,
      latitude: 3,
    );
    final result = await service.replaceStopRouteAware(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [anchor, old]),
        ],
        ranked: [anchor, old, scoreFavorite, routeFavorite],
      ),
      'old-breakfast',
      routeDurationHours: (_, _, destinationLatitude, _) async =>
          destinationLatitude == 3 ? 0.1 : 0.8,
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places.last.place.id, 'route-favorite');
    expect(result.message, contains('Google driving time'));
    expect(result.message, contains('6 min'));
  });

  test('closer replacement falls back when live routes fail', () async {
    final anchor = _place('anchor', latitude: 1);
    final old = _place('old', latitude: 2);
    final fallback = _place('fallback', score: 90, latitude: 3);
    final result = await service.replaceStopRouteAware(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [anchor, old]),
        ],
        ranked: [anchor, old, fallback],
      ),
      'old',
      routeDurationHours: (_, _, _, _) async => throw Exception('offline'),
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places.last.place.id, 'fallback');
    expect(result.message, contains('distance score'));
  });

  test(
    'closer replacement keeps the current stop when it is nearest',
    () async {
      final anchor = _place('anchor', latitude: 1);
      final old = _place('old', latitude: 2);
      final alternative = _place('alternative', latitude: 3);
      final result = await service.replaceStopRouteAware(
        _plan(
          days: [
            PlannerDay(dayNumber: 1, places: [anchor, old]),
          ],
          ranked: [anchor, old, alternative],
        ),
        'old',
        routeDurationHours: (_, _, destinationLatitude, _) async =>
            destinationLatitude == 2 ? 0.1 : 0.2,
      );

      expect(result.changed, isFalse);
      expect(result.plan.days.single.places.last.place.id, 'old');
      expect(result.message, contains('already the closest'));
    },
  );

  test('swaps scheduled stops across different days', () {
    final first = _place('first');
    final second = _place('second');
    final result = service.swapStops(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [first]),
          PlannerDay(dayNumber: 2, places: [second]),
        ],
      ),
      'first',
      'second',
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places.single.place.id, 'second');
    expect(result.plan.days.last.places.single.place.id, 'first');
  });

  test('replaces one scheduled stop using another scheduled stop', () {
    final first = _place('first');
    final second = _place('second');
    final result = service.replaceWithScheduledStop(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [first]),
          PlannerDay(dayNumber: 2, places: [second]),
        ],
      ),
      'first',
      'second',
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places.single.place.id, 'second');
    expect(result.plan.days.last.places, isEmpty);
  });

  test('moves a stop before another stop', () {
    final first = _place('first');
    final second = _place('second');
    final third = _place('third');
    final result = service.moveStopRelative(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [first, second, third]),
        ],
      ),
      'third',
      'first',
      'before',
    );

    expect(result.plan.days.single.places.map((item) => item.place.id), [
      'third',
      'first',
      'second',
    ]);
  });

  test('moves a stop to an exact non-conflicting time on another day', () {
    final first = _place('first');
    final second = _place('second');
    final result = service.moveStopToTime(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [first]),
          PlannerDay(dayNumber: 2, places: [second]),
        ],
      ),
      'first',
      2,
      14 * 60,
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.first.places, isEmpty);
    expect(result.plan.startTimeOverrides['first'], 14 * 60);
  });

  test('reschedules an entire day from a requested start time', () {
    final first = _place('first');
    final second = _place('second');
    final result = service.setDayStartTime(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [first, second]),
        ],
      ),
      1,
      9 * 60,
    );

    expect(result.changed, isTrue);
    expect(result.plan.startTimeOverrides['first'], 9 * 60 + 30);
    expect(result.plan.startTimeOverrides['second'], 11 * 60 + 30);
  });

  test('rejects a late day start when all stops cannot fit', () {
    final result = service.setDayStartTime(
      _plan(
        days: [
          PlannerDay(
            dayNumber: 1,
            places: List.generate(4, (index) => _place('place-$index')),
          ),
        ],
      ),
      1,
      20 * 60,
    );

    expect(result.changed, isFalse);
    expect(result.message, contains('past midnight'));
  });

  test('adds an exact number of safe unused activities to one day', () {
    final scheduled = _place('scheduled');
    final result = service.addStops(
      _plan(
        days: [
          PlannerDay(dayNumber: 1, places: [scheduled]),
        ],
        ranked: [
          scheduled,
          _place('candidate-1'),
          _place('candidate-2'),
          _place('candidate-3'),
        ],
      ),
      dayNumber: 1,
      requestedCount: 2,
    );

    expect(result.changed, isTrue);
    expect(result.plan.days.single.places, hasLength(3));
  });

  test('removes an exact number of lowest-priority optional stops', () {
    final result = service.removeStops(
      _plan(
        days: [
          PlannerDay(
            dayNumber: 1,
            places: [
              _place('high', score: 90),
              _place('low', score: 40),
              _place('middle', score: 60),
              _place('meal', category: 'restaurant'),
            ],
          ),
        ],
      ),
      dayNumber: 1,
      count: 2,
    );

    expect(
      result.plan.days.single.places.map((item) => item.place.id),
      containsAll(['high', 'meal']),
    );
    expect(result.plan.days.single.places, hasLength(2));
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

ScoredPlace _place(
  String id, {
  String category = 'park',
  double score = 80,
  double rating = 4.5,
  double cost = 10,
  double latitude = 0,
  double longitude = 0,
}) {
  return ScoredPlace(
    place: TravelPlace(
      id: id,
      name: id,
      category: category,
      tags: [category],
      rating: rating,
      reviewCount: 1000,
      cost: CostEstimate(
        low: cost,
        high: cost,
        currencyCode: 'USD',
        source: CostSource.userProvided,
      ),
      latitude: latitude,
      longitude: longitude,
      estimatedVisitMinutes: 90,
    ),
    totalScore: score,
    ratingScore: 80,
    reviewScore: 80,
    preferenceScore: 80,
    budgetScore: 80,
    distanceScore: 80,
  );
}
