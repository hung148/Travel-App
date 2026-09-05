import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/cost_estimate.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/planner_validation.dart';
import 'package:travel/models/budget_allocation.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/place_scoring_service.dart';

void main() {
  group('PlannerProfile', () {
    test('maps activity levels to distinct planner strategies', () {
      final relaxed = PlannerProfile.fromActivityLevel('Relaxed');
      final balanced = PlannerProfile.fromActivityLevel('Moderate');
      final explorer = PlannerProfile.fromActivityLevel('Very Active');

      expect(relaxed, same(PlannerProfile.relaxed));
      expect(balanced, same(PlannerProfile.balanced));
      expect(explorer, same(PlannerProfile.explorer));
      expect(relaxed.maxPlacesPerDay, lessThan(balanced.maxPlacesPerDay));
      expect(balanced.maxPlacesPerDay, lessThan(explorer.maxPlacesPerDay));
      expect(relaxed.targetMinutesPerDay, 300);
      expect(balanced.targetMinutesPerDay, 420);
      expect(explorer.targetMinutesPerDay, 570);
      expect(relaxed.minDiningPlacesPerDay, 3);
      expect(balanced.minDiningPlacesPerDay, 3);
      expect(explorer.minDiningPlacesPerDay, 3);
      expect(
        relaxed.distanceToleranceKm,
        lessThan(explorer.distanceToleranceKm),
      );
    });

    test('every strategy has normalized scoring weights', () {
      for (final profile in [
        PlannerProfile.relaxed,
        PlannerProfile.balanced,
        PlannerProfile.explorer,
      ]) {
        expect(profile.scoringWeights.total, closeTo(1, 0.0001));
      }
    });
  });

  test('distance tolerance changes scoring between strategies', () {
    const place = TravelPlace(
      id: 'far-place',
      name: 'Far Place',
      category: 'museum',
      tags: ['history'],
      rating: 4.5,
      reviewCount: 1000,
      cost: const CostEstimate(
        low: 20,
        high: 20,
        currencyCode: 'USD',
        source: CostSource.userProvided,
      ),
      latitude: 0.07,
      longitude: 0,
      estimatedVisitMinutes: 90,
    );
    final preference = Preference(
      id: 'preference',
      ownerId: 'user',
      experienceType: const ['history'],
      activityLevel: 'Moderate',
      spendingStyle: 'Normal',
      interests: const ['museum'],
    );
    final service = PlaceScoringService();

    final relaxed = service.scorePlace(
      place: place,
      preference: preference,
      dailyActivityBudget: 100,
      centerLatitude: 0,
      centerLongitude: 0,
      profile: PlannerProfile.relaxed,
    );
    final explorer = service.scorePlace(
      place: place,
      preference: preference,
      dailyActivityBudget: 100,
      centerLatitude: 0,
      centerLongitude: 0,
      profile: PlannerProfile.explorer,
    );

    expect(relaxed.distanceScore, 20);
    expect(explorer.distanceScore, 65);
    expect(explorer.totalScore, greaterThan(relaxed.totalScore));
  });

  test('planner result totals the estimated expense across all days', () {
    const place = TravelPlace(
      id: 'place',
      name: 'Place',
      category: 'museum',
      tags: [],
      rating: 4,
      reviewCount: 100,
      cost: const CostEstimate(
        low: 25,
        high: 25,
        currencyCode: 'USD',
        source: CostSource.userProvided,
      ),
      latitude: 0,
      longitude: 0,
      estimatedVisitMinutes: 60,
    );
    const scoredPlace = ScoredPlace(
      place: place,
      totalScore: 80,
      ratingScore: 80,
      reviewScore: 80,
      preferenceScore: 80,
      budgetScore: 80,
      distanceScore: 80,
    );
    const result = PlannerResult(
      budgetAllocation: BudgetAllocation(
        total: 1000,
        accommodation: 400,
        food: 200,
        transportation: 150,
        activities: 200,
        buffer: 50,
      ),
      validation: PlannerValidationResult(issues: []),
      profile: PlannerProfile.balanced,
      rankedPlaces: [scoredPlace],
      days: [
        PlannerDay(dayNumber: 1, places: [scoredPlace]),
        PlannerDay(dayNumber: 2, places: [scoredPlace, scoredPlace]),
      ],
    );

    expect(result.totalEstimatedCost, 75);
  });
}
