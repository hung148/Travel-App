import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/cost_estimate.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/planner_validation.dart';
import 'package:travel/models/spending_profile.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/service/budget_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  const budgetService = BudgetService();

  group('BudgetService', () {
    test('allocates every dollar across the five budget categories', () {
      final allocation = budgetService.allocate(
        totalBudget: 2000,
        spendingStyle: 'Normal',
      );

      expect(allocation.accommodation, closeTo(760, 0.001));
      expect(allocation.food, closeTo(440, 0.001));
      expect(allocation.transportation, closeTo(280, 0.001));
      expect(allocation.activities, closeTo(420, 0.001));
      expect(allocation.buffer, closeTo(100, 0.001));
      expect(allocation.allocatedTotal, closeTo(allocation.total, 0.001));
      expect(allocation.dailyActivitiesBudget(4), closeTo(105, 0.001));
    });

    test('changes allocation according to spending style', () {
      final budget = budgetService.allocate(
        totalBudget: 1000,
        spendingStyle: 'Budget',
      );
      final luxury = budgetService.allocate(
        totalBudget: 1000,
        spendingStyle: 'Luxury',
      );

      final normal = budgetService.allocate(
        totalBudget: 1000,
        spendingStyle: 'Normal',
      );

      expect(budget.activities, closeTo(160, 0.001));
      expect(budget.buffer, closeTo(120, 0.001));
      expect(luxury.activities, closeTo(220, 0.001));
      expect(luxury.accommodation, closeTo(410, 0.001));

      // The three styles have to actually differ, or the user sees the same
      // plan whichever one they pick - which is the bug this guards.
      expect(budget.accommodation, lessThan(normal.accommodation));
      expect(normal.accommodation, lessThan(luxury.accommodation));
      expect(luxury.buffer, lessThan(budget.buffer));
    });

    test('moves available buffer into food when required', () {
      final allocation = budgetService.allocate(
        totalBudget: 1000,
        spendingStyle: 'Budget',
      );
      final adjusted = budgetService.ensureMinimumFoodBudget(
        allocation: allocation,
        minimumFoodBudget: 280,
      );

      expect(adjusted, isNotNull);
      expect(adjusted!.food, closeTo(280, 0.001));
      expect(adjusted.buffer, closeTo(80, 0.001));
      expect(adjusted.allocatedTotal, closeTo(adjusted.total, 0.001));
    });
  });

  group('SpendingProfile', () {
    test('every style spends the whole budget', () {
      for (final profile in SpendingProfile.values) {
        final sum =
            profile.accommodationShare +
            profile.foodShare +
            profile.transportationShare +
            profile.activitiesShare +
            profile.bufferShare;
        expect(sum, closeTo(1, 0.0001), reason: profile.label);
      }
    });

    test('a cheap stop delights Budget and disappoints Luxury', () {
      double fit(SpendingProfile profile) =>
          profile.costFitScore(placeCost: 20, dailyBudget: 150);

      expect(fit(SpendingProfile.budget), 100);
      expect(
        fit(SpendingProfile.normal),
        lessThan(fit(SpendingProfile.budget)),
      );
      expect(
        fit(SpendingProfile.luxury),
        lessThan(fit(SpendingProfile.normal)),
      );
    });

    test('a stop worth most of the day suits Luxury, not Budget', () {
      double fit(SpendingProfile profile) =>
          profile.costFitScore(placeCost: 90, dailyBudget: 150);

      expect(fit(SpendingProfile.luxury), 100);
      expect(fit(SpendingProfile.budget), lessThan(fit(SpendingProfile.normal)));
      expect(fit(SpendingProfile.normal), lessThan(fit(SpendingProfile.luxury)));
    });

    test('a stop that eats the whole day is a bad pick for every style', () {
      for (final profile in SpendingProfile.values) {
        expect(
          profile.costFitScore(placeCost: 400, dailyBudget: 150),
          8,
          reason: profile.label,
        );
      }
    });

    test('unknown styles fall back to Normal', () {
      expect(SpendingProfile.fromName(null), same(SpendingProfile.normal));
      expect(SpendingProfile.fromName(''), same(SpendingProfile.normal));
      expect(SpendingProfile.fromName('  BUDGET '), same(SpendingProfile.budget));
      expect(SpendingProfile.fromName('Premium'), same(SpendingProfile.luxury));
    });
  });

  test('spending style changes which place ranks first', () {
    const cheap = TravelPlace(
      id: 'cheap',
      name: 'Cheap Museum',
      category: 'museum',
      tags: ['museum'],
      rating: 4.2,
      reviewCount: 500,
      cost: CostEstimate(
        low: 20,
        high: 20,
        currencyCode: 'USD',
        source: CostSource.userProvided,
      ),
      latitude: 0,
      longitude: 0,
      estimatedVisitMinutes: 60,
    );
    const premium = TravelPlace(
      id: 'premium',
      name: 'Premium Museum',
      category: 'museum',
      tags: ['museum'],
      rating: 4.6,
      reviewCount: 500,
      cost: CostEstimate(
        low: 90,
        high: 90,
        currencyCode: 'USD',
        source: CostSource.userProvided,
      ),
      latitude: 0,
      longitude: 0,
      estimatedVisitMinutes: 60,
    );

    const service = PlaceScoringService();

    List<String> rankedIds(String spendingStyle) {
      return service
          .rankPlaces(
            places: const [cheap, premium],
            preference: Preference(
              id: 'preference',
              ownerId: 'user',
              experienceType: const ['Culture'],
              activityLevel: 'Moderate',
              spendingStyle: spendingStyle,
              interests: const ['Museums'],
            ),
            dailyActivityBudget: 150,
            centerLatitude: 0,
            centerLongitude: 0,
            profile: PlannerProfile.balanced,
          )
          .map((item) => item.place.id)
          .toList();
    }

    // The whole point of the fix: identical candidates, different order.
    expect(rankedIds('Budget').first, 'cheap');
    expect(rankedIds('Luxury').first, 'premium');
  });

  test('planner selects attractions using only the activities allocation', () {
    final planner = TravelPlannerService(
      placeScoringService: const PlaceScoringService(),
    );
    final result = planner.generatePlan(
      trip: Trip(
        id: 'trip',
        ownerId: 'user',
        destination: 'City',
        budget: 1000,
        days: 1,
        status: 'draft',
      ),
      preference: Preference(
        id: 'preference',
        ownerId: 'user',
        experienceType: const ['Culture'],
        activityLevel: 'Moderate',
        spendingStyle: 'Budget',
        interests: const ['Museums'],
      ),
      candidatePlaces: const [
        TravelPlace(
          id: 'too-expensive',
          name: 'Too Expensive',
          category: 'museum',
          tags: ['museum'],
          rating: 5,
          reviewCount: 1000,
          cost: CostEstimate(
            low: 200,
            high: 200,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 60,
        ),
        TravelPlace(
          id: 'fits-activities',
          name: 'Fits Activities',
          category: 'museum',
          tags: ['museum'],
          rating: 4,
          reviewCount: 500,
          cost: CostEstimate(
            low: 150,
            high: 150,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 60,
        ),
        TravelPlace(
          id: 'breakfast',
          name: 'Breakfast',
          category: 'cafe',
          tags: ['cafe'],
          rating: 4,
          reviewCount: 100,
          cost: CostEstimate(
            low: 10,
            high: 10,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 45,
        ),
        TravelPlace(
          id: 'lunch',
          name: 'Lunch',
          category: 'restaurant',
          tags: ['restaurant'],
          rating: 4,
          reviewCount: 100,
          cost: CostEstimate(
            low: 10,
            high: 10,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 60,
        ),
        TravelPlace(
          id: 'dinner',
          name: 'Dinner',
          category: 'sushi_restaurant',
          tags: ['sushi_restaurant'],
          rating: 4,
          reviewCount: 100,
          cost: CostEstimate(
            low: 10,
            high: 10,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 75,
        ),
      ],
      centerLatitude: 0,
      centerLongitude: 0,
    );

    expect(result.budgetAllocation.activities, closeTo(160, 0.001));
    expect(result.validation.warnings, isEmpty);
    expect(
      result.days.single.places
          .where((item) => !item.place.isDining)
          .single
          .place
          .id,
      'fits-activities',
    );
    expect(result.days.single.estimatedActivityCost, 150);
  });

  test('planner rejects a budget that cannot fund three meals', () {
    final planner = TravelPlannerService(
      placeScoringService: const PlaceScoringService(),
    );
    final result = planner.generatePlan(
      trip: Trip(
        id: 'trip',
        ownerId: 'user',
        destination: 'City',
        budget: 100,
        days: 1,
        status: 'draft',
      ),
      preference: Preference(
        id: 'preference',
        ownerId: 'user',
        experienceType: const ['food'],
        activityLevel: 'Relaxed',
        spendingStyle: 'Budget',
        interests: const ['local food'],
      ),
      candidatePlaces: const [
        TravelPlace(
          id: 'a',
          name: 'a',
          category: 'cafe',
          tags: ['cafe'],
          rating: 4,
          reviewCount: 10,
          cost: CostEstimate(
            low: 50,
            high: 50,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 45,
        ),
        TravelPlace(
          id: 'b',
          name: 'b',
          category: 'restaurant',
          tags: ['restaurant'],
          rating: 4,
          reviewCount: 10,
          cost: CostEstimate(
            low: 50,
            high: 50,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 60,
        ),
        TravelPlace(
          id: 'c',
          name: 'c',
          category: 'sushi_restaurant',
          tags: ['sushi_restaurant'],
          rating: 4,
          reviewCount: 10,
          cost: CostEstimate(
            low: 50,
            high: 50,
            currencyCode: 'USD',
            source: CostSource.userProvided,
          ),
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 75,
        ),
      ],
      centerLatitude: 0,
      centerLongitude: 0,
    );

    expect(result.days.single.places, isEmpty);
    expect(result.validation.isValid, isFalse);
    expect(
      result.validation.errors.single.code,
      PlannerValidationCode.insufficientBudgetForRequiredMeals,
    );
  });
}
