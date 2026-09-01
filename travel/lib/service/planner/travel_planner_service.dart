import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/place_role.dart';
import '../../models/preference/preferences.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import '../budget_service.dart';
import 'daily_composition_service.dart';
import 'place_role_classifier.dart';
import 'place_scoring_service.dart';
import 'planner_validation_service.dart';
import 'route_optimizer.dart';

class TravelPlannerService {
  final PlaceScoringService placeScoringService;
  final RouteOptimizer routeOptimizer;
  final BudgetService budgetService;
  final PlannerValidationService validationService;
  final PlaceRoleClassifier roleClassifier;
  final DailyCompositionService compositionService;

  TravelPlannerService({
    required this.placeScoringService,
    this.routeOptimizer = const RouteOptimizer(),
    this.budgetService = const BudgetService(),
    this.validationService = const PlannerValidationService(),
    this.roleClassifier = const PlaceRoleClassifier(),
    this.compositionService = const DailyCompositionService(),
  });

  PlannerResult generatePlan({
    required Trip trip,
    required Preference preference,
    required List<TravelPlace> candidatePlaces,
    required double centerLatitude,
    required double centerLongitude,
  }) {
    final profile = PlannerProfile.fromActivityLevel(preference.activityLevel);
    final budgetAllocation = budgetService.allocate(
      totalBudget: trip.budget,
      spendingStyle: preference.spendingStyle,
    );

    if (trip.days <= 0) {
      throw ArgumentError('Trip must have at least one day.');
    }

    final days = List.generate(
      trip.days,
      (index) => PlannerDay(dayNumber: index + 1, places: []),
    );

    if (candidatePlaces.isEmpty) {
      final validation = validationService.validate(
        days: days,
        rankedPlaces: const [],
        profile: profile,
        budgetAllocation: budgetAllocation,
      );
      return PlannerResult(
        budgetAllocation: budgetAllocation,
        validation: validation,
        profile: profile,
        rankedPlaces: const [],
        days: days,
      );
    }

    final dailyActivityBudget = budgetAllocation.dailyActivitiesBudget(
      trip.days,
    );

    final rankedPlaces = placeScoringService.rankPlaces(
      places: candidatePlaces,
      preference: preference,
      dailyActivityBudget: dailyActivityBudget,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      profile: profile,
    );

    _distributePlaces(
      rankedPlaces: rankedPlaces,
      days: days,
      profile: profile,
      dailyActivityBudget: dailyActivityBudget,
    );

    _optimizeDailyRoutes(
      days: days,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );

    _composeDays(days: days, profile: profile);

    final validation = validationService.validate(
      days: days,
      rankedPlaces: rankedPlaces,
      profile: profile,
      budgetAllocation: budgetAllocation,
    );

    return PlannerResult(
      budgetAllocation: budgetAllocation,
      validation: validation,
      profile: profile,
      rankedPlaces: rankedPlaces,
      days: days,
    );
  }

  void _composeDays({
    required List<PlannerDay> days,
    required PlannerProfile profile,
  }) {
    for (final day in days) {
      final arranged = compositionService.arrange(
        routeOrderedPlaces: day.places,
        profile: profile,
      );
      day.places
        ..clear()
        ..addAll(arranged);
    }
  }

  void _optimizeDailyRoutes({
    required List<PlannerDay> days,
    required double centerLatitude,
    required double centerLongitude,
  }) {
    for (final day in days) {
      final optimized = routeOptimizer.optimize(
        places: day.places,
        startLatitude: centerLatitude,
        startLongitude: centerLongitude,
      );

      day.places
        ..clear()
        ..addAll(optimized);
    }
  }

  void _distributePlaces({
    required List<ScoredPlace> rankedPlaces,
    required List<PlannerDay> days,
    required PlannerProfile profile,
    required double dailyActivityBudget,
  }) {
    final dayCosts = List<double>.filled(days.length, 0);
    final dayMinutes = List<int>.filled(days.length, 0);
    final dayDiningCounts = List<int>.filled(days.length, 0);
    int dayIndex = 0;

    for (final scoredPlace in rankedPlaces) {
      int attempts = 0;

      while (attempts < days.length) {
        final day = days[dayIndex];
        final hasSpace = day.places.length < profile.maxPlacesPerDay;
        final projectedCost =
            dayCosts[dayIndex] + scoredPlace.place.estimatedCost;
        final withinBudget = projectedCost <= dailyActivityBudget;
        final projectedMinutes =
            dayMinutes[dayIndex] + scoredPlace.place.estimatedVisitMinutes;
        final withinTime = projectedMinutes <= profile.targetMinutesPerDay;
        final isDining =
            roleClassifier.classify(scoredPlace.place) == PlaceRole.dining;
        final withinDiningLimit =
            !isDining ||
            dayDiningCounts[dayIndex] < profile.maxDiningPlacesPerDay;

        if (hasSpace && withinBudget && withinTime && withinDiningLimit) {
          day.places.add(scoredPlace);
          dayCosts[dayIndex] = projectedCost;
          dayMinutes[dayIndex] = projectedMinutes;
          if (isDining) dayDiningCounts[dayIndex]++;
          dayIndex = (dayIndex + 1) % days.length;
          break;
        }

        dayIndex = (dayIndex + 1) % days.length;
        attempts++;
      }
    }
  }
}
