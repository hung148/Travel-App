import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/preference/preferences.dart';
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
      ],
      centerLatitude: 0,
      centerLongitude: 0,
    );

    expect(result.budgetAllocation.activities, 180);
    expect(result.days.single.places.single.place.id, 'fits-activities');
    expect(result.totalEstimatedCost, 150);
  });
}
