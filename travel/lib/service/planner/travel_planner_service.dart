import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/planner_validation.dart';
import '../../models/budget_allocation.dart';
import '../../models/preference/preferences.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import '../budget_service.dart';
import 'daily_composition_service.dart';
import 'place_scoring_service.dart';
import 'planner_validation_service.dart';
import 'route_optimizer.dart';

class TravelPlannerService {
  final PlaceScoringService placeScoringService;
  final RouteOptimizer routeOptimizer;
  final BudgetService budgetService;
  final PlannerValidationService validationService;
  final DailyCompositionService compositionService;

  TravelPlannerService({
    required this.placeScoringService,
    this.routeOptimizer = const RouteOptimizer(),
    this.budgetService = const BudgetService(),
    this.validationService = const PlannerValidationService(),
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
    final eligibleCandidatePlaces = candidatePlaces
        .where((place) => !_isStandaloneRetailStore(place))
        .toList();
    var budgetAllocation = budgetService.allocate(
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

    if (eligibleCandidatePlaces.isEmpty) {
      final validation = _requireWarningFree(
        validationService.validate(
          days: days,
          rankedPlaces: const [],
          profile: profile,
          budgetAllocation: budgetAllocation,
        ),
      );
      return PlannerResult(
        budgetAllocation: budgetAllocation,
        validation: validation,
        profile: profile,
        rankedPlaces: const [],
        days: days,
      );
    }

    var rankedPlaces = placeScoringService.rankPlaces(
      places: eligibleCandidatePlaces,
      preference: preference,
      dailyActivityBudget: budgetAllocation.dailyActivitiesBudget(trip.days),
      dailyFoodBudget: budgetAllocation.dailyFoodBudget(trip.days),
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      profile: profile,
    );

    final diningCandidates = rankedPlaces
        .where((item) => item.place.isDining)
        .toList();
    final requiredMealCount = trip.days * profile.minDiningPlacesPerDay;
    if (diningCandidates.length < requiredMealCount) {
      return _failedResult(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
        code: PlannerValidationCode.insufficientDiningCandidates,
        message:
            'Only ${diningCandidates.length} unique meal places were found, but $requiredMealCount are required for three meals per day. Create this trip manually or shorten it.',
      );
    }

    final cheapestDiningPlan = _buildDiningPlan(
      diningCandidates: [...diningCandidates]
        ..sort(
          (left, right) =>
              left.place.estimatedCost.compareTo(right.place.estimatedCost),
        ),
      dayCount: trip.days,
      mealsPerDay: profile.minDiningPlacesPerDay,
    );
    final minimumFoodAllocation =
        cheapestDiningPlan.maximumDailyCost * trip.days;
    final adjustedAllocation = budgetService.ensureMinimumFoodBudget(
      allocation: budgetAllocation,
      minimumFoodBudget: minimumFoodAllocation,
    );
    if (adjustedAllocation == null) {
      return _failedResult(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
        code: PlannerValidationCode.insufficientBudgetForRequiredMeals,
        message:
            'This budget cannot cover three meals per day. At least \$${minimumFoodAllocation.toStringAsFixed(0)} must be available for food; increase the total budget or create the trip manually.',
      );
    }
    budgetAllocation = adjustedAllocation;

    rankedPlaces = placeScoringService.rankPlaces(
      places: eligibleCandidatePlaces,
      preference: preference,
      dailyActivityBudget: budgetAllocation.dailyActivitiesBudget(trip.days),
      dailyFoodBudget: budgetAllocation.dailyFoodBudget(trip.days),
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      profile: profile,
    );
    final preferredDiningPlan = _buildDiningPlan(
      diningCandidates: rankedPlaces
          .where((item) => item.place.isDining)
          .toList(),
      dayCount: trip.days,
      mealsPerDay: profile.minDiningPlacesPerDay,
    );
    final diningPlan =
        preferredDiningPlan.maximumDailyCost <=
            budgetAllocation.dailyFoodBudget(trip.days) + 0.001
        ? preferredDiningPlan
        : cheapestDiningPlan;

    final dailyActivityBudget = budgetAllocation.dailyActivitiesBudget(
      trip.days,
    );

    _distributePlaces(
      rankedPlaces: rankedPlaces,
      days: days,
      profile: profile,
      dailyActivityBudget: dailyActivityBudget,
      diningPlan: diningPlan,
    );

    _optimizeDailyRoutes(
      days: days,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );

    _composeDays(days: days, profile: profile);

    final validation = _requireWarningFree(
      validationService.validate(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
      ),
    );

    return PlannerResult(
      budgetAllocation: budgetAllocation,
      validation: validation,
      profile: profile,
      rankedPlaces: rankedPlaces,
      days: days,
    );
  }

  /// Individual retail businesses are not itinerary attractions. Actual malls
  /// remain eligible even when Google also attaches one or more store types.
  bool _isStandaloneRetailStore(TravelPlace place) {
    final types = {
      place.category,
      ...place.tags,
    }.map((value) => value.toLowerCase().trim()).toSet();
    if (types.contains('shopping_mall')) return false;
    return types.contains('store') ||
        types.any((type) => type.endsWith('_store'));
  }

  PlannerValidationResult _requireWarningFree(
    PlannerValidationResult validation,
  ) {
    return PlannerValidationResult(
      issues: validation.issues
          .map(
            (issue) => issue.severity == PlannerValidationSeverity.warning
                ? PlannerValidationIssue(
                    code: issue.code,
                    severity: PlannerValidationSeverity.error,
                    message: issue.message,
                    dayNumber: issue.dayNumber,
                  )
                : issue,
          )
          .toList(),
    );
  }

  PlannerResult _failedResult({
    required List<PlannerDay> days,
    required List<ScoredPlace> rankedPlaces,
    required PlannerProfile profile,
    required BudgetAllocation budgetAllocation,
    required PlannerValidationCode code,
    required String message,
  }) {
    return PlannerResult(
      budgetAllocation: budgetAllocation,
      validation: PlannerValidationResult(
        issues: [
          PlannerValidationIssue(
            code: code,
            severity: PlannerValidationSeverity.error,
            message: message,
          ),
        ],
      ),
      profile: profile,
      rankedPlaces: rankedPlaces,
      days: days,
    );
  }

  _DiningPlan _buildDiningPlan({
    required List<ScoredPlace> diningCandidates,
    required int dayCount,
    required int mealsPerDay,
  }) {
    final selected = diningCandidates.take(dayCount * mealsPerDay).toList()
      ..sort(
        (left, right) =>
            right.place.estimatedCost.compareTo(left.place.estimatedCost),
      );
    final byDay = List.generate(dayCount, (_) => <ScoredPlace>[]);
    final dayCosts = List<double>.filled(dayCount, 0);

    for (final meal in selected) {
      var targetDay = 0;
      for (var dayIndex = 1; dayIndex < dayCount; dayIndex++) {
        final targetIsFull = byDay[targetDay].length >= mealsPerDay;
        final candidateHasSpace = byDay[dayIndex].length < mealsPerDay;
        if (candidateHasSpace &&
            (targetIsFull || dayCosts[dayIndex] < dayCosts[targetDay])) {
          targetDay = dayIndex;
        }
      }
      byDay[targetDay].add(meal);
      dayCosts[targetDay] += meal.place.estimatedCost;
    }

    return _DiningPlan(
      byDay: byDay,
      maximumDailyCost: dayCosts.reduce(
        (left, right) => left > right ? left : right,
      ),
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
    required _DiningPlan diningPlan,
  }) {
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      days[dayIndex].places.addAll(diningPlan.byDay[dayIndex]);
    }

    final activityPlaces = rankedPlaces
        .where((item) => !item.place.isDining)
        .toList();
    final dayCosts = List<double>.filled(days.length, 0);
    final dayMinutes = List<int>.filled(days.length, 0);
    int dayIndex = 0;

    for (final scoredPlace in activityPlaces) {
      int attempts = 0;

      while (attempts < days.length) {
        final day = days[dayIndex];
        final hasSpace = day.activityCount < profile.maxPlacesPerDay;
        final projectedCost =
            dayCosts[dayIndex] + scoredPlace.place.estimatedCost;
        final withinBudget = projectedCost <= dailyActivityBudget;
        final projectedMinutes =
            dayMinutes[dayIndex] + scoredPlace.place.estimatedVisitMinutes;
        final withinTime = projectedMinutes <= profile.targetMinutesPerDay;

        if (hasSpace && withinBudget && withinTime) {
          day.places.add(scoredPlace);
          dayCosts[dayIndex] = projectedCost;
          dayMinutes[dayIndex] = projectedMinutes;
          dayIndex = (dayIndex + 1) % days.length;
          break;
        }

        dayIndex = (dayIndex + 1) % days.length;
        attempts++;
      }
    }
  }
}

class _DiningPlan {
  final List<List<ScoredPlace>> byDay;
  final double maximumDailyCost;

  const _DiningPlan({required this.byDay, required this.maximumDailyCost});
}
