import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/planner_validation.dart';
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

      expect(allocation.accommodation, 800);
      expect(allocation.food, 400);
      expect(allocation.transportation, 300);
      expect(allocation.activities, 400);
      expect(allocation.buffer, 100);
      expect(allocation.allocatedTotal, closeTo(allocation.total, 0.001));
      expect(allocation.dailyActivitiesBudget(4), 100);
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

      expect(budget.activities, 180);
      expect(budget.buffer, 100);
      expect(luxury.activities, 250);
      expect(luxury.accommodation, 400);
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
      expect(adjusted!.food, 280);
      expect(adjusted.buffer, 40);
      expect(adjusted.allocatedTotal, closeTo(adjusted.total, 0.001));
    });
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
          estimatedCost: 200,
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
          estimatedCost: 150,
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
          estimatedCost: 10,
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
          estimatedCost: 10,
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
          estimatedCost: 10,
          latitude: 0,
          longitude: 0,
          estimatedVisitMinutes: 75,
        ),
      ],
      centerLatitude: 0,
      centerLongitude: 0,
    );

    expect(result.budgetAllocation.activities, 180);
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
          estimatedCost: 50,
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
          estimatedCost: 50,
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
          estimatedCost: 50,
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
