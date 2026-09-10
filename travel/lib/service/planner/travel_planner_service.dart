import '../../core/utils/money.dart';
import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/planner_validation.dart';
import '../../models/place_role.dart';
import '../../models/budget_allocation.dart';
import '../../models/preference/preferences.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import '../budget_service.dart';
import 'daily_composition_service.dart';
import 'dining_selection_service.dart';
import 'place_scoring_service.dart';
import 'planner_validation_service.dart';
import 'route_optimizer.dart';
import 'place_quality_service.dart';
import 'daily_time_schedule_service.dart';

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
    double? accommodationCost,
  }) {
    final profile = PlannerProfile.fromActivityLevel(preference.activityLevel);
    // The budget is the WHOLE party's money, but every place cost is per
    // person. Both facts have to be in scope for any comparison to be valid.
    final travelers = trip.travelers < 1 ? 1 : trip.travelers;
    final currency = Money.normalize(trip.currencyCode);
    final eligibleCandidatePlaces = candidatePlaces
        .where((place) => !_isInvalidRetailCandidate(place))
        .where(
          (place) => !const PlaceQualityService().excluded(
            name: place.name,
            types: {place.category, ...place.tags},
          ),
        )
        .toList();
    var budgetAllocation = budgetService.allocateForTrip(
      totalBudget: trip.budget,
      accommodationCost: accommodationCost,
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
          travelers: travelers,
          currencyCode: currency,
        ),
      );
      return PlannerResult(
        budgetAllocation: budgetAllocation,
        validation: validation,
        profile: profile,
        rankedPlaces: const [],
        days: days,
        travelers: travelers,
        currencyCode: currency,
      );
    }

    var rankedPlaces = placeScoringService.rankPlaces(
      places: eligibleCandidatePlaces,
      preference: preference,
      dailyActivityBudget: budgetAllocation.dailyActivitiesBudgetPerPerson(
        trip.days,
        travelers,
      ),
      dailyFoodBudget: budgetAllocation.dailyFoodBudgetPerPerson(
        trip.days,
        travelers,
      ),
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      profile: profile,
    );

    final diningCandidates = rankedPlaces
        .where((item) => item.place.isDining)
        .toList();
    final requiredMealCount = profile.minDiningPlacesPerDay;
    if (diningCandidates.length < requiredMealCount) {
      return _failedResult(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
        travelers: travelers,
        currencyCode: currency,
        code: PlannerValidationCode.insufficientDiningCandidates,
        message:
            'Only ${diningCandidates.length} meal places were found. At least $requiredMealCount are needed for three different meals each day; restaurants can be revisited on later days.',
      );
    }

    final cheapestDailyMeals =
        ([...diningCandidates]..sort(
              (left, right) =>
                  left.place.estimatedCost.compareTo(right.place.estimatedCost),
            ))
            .take(profile.minDiningPlacesPerDay);
    // Repeats are allowed across days, so the real floor is the cheapest
    // complete day, not a trip's worth of increasingly expensive unique meals.
    final minimumFoodAllocation =
        cheapestDailyMeals.fold<double>(
          0,
          (sum, meal) => sum + meal.place.estimatedCost,
        ) *
        trip.days *
        travelers;
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
        travelers: travelers,
        currencyCode: currency,
        code: PlannerValidationCode.insufficientBudgetForRequiredMeals,
        message:
            'This budget cannot cover three meals per day for $travelers '
            '${travelers == 1 ? 'traveler' : 'travelers'}. At least '
            '${Money.format(minimumFoodAllocation, currency)} must be '
            'available for food; increase the total budget or create the trip '
            'manually.',
      );
    }
    budgetAllocation = adjustedAllocation;

    rankedPlaces = placeScoringService.rankPlaces(
      places: eligibleCandidatePlaces,
      preference: preference,
      dailyActivityBudget: budgetAllocation.dailyActivitiesBudgetPerPerson(
        trip.days,
        travelers,
      ),
      dailyFoodBudget: budgetAllocation.dailyFoodBudgetPerPerson(
        trip.days,
        travelers,
      ),
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      profile: profile,
    );
    late final List<List<ScoredPlace>> diningDays;
    try {
      diningDays = const DiningSelectionService().select(
        candidates: rankedPlaces.where((item) => item.place.isDining).toList(),
        days: trip.days,
        mealsPerDay: profile.minDiningPlacesPerDay,
        dailyBudget: budgetAllocation.dailyFoodBudgetPerPerson(
          trip.days,
          travelers,
        ),
        spendingStyle: preference.spendingStyle,
      );
    } on StateError catch (error) {
      return _failedResult(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
        travelers: travelers,
        currencyCode: currency,
        code: PlannerValidationCode.insufficientBudgetForRequiredMeals,
        message: error.message,
      );
    }

    final dailyActivityBudget = budgetAllocation.dailyActivitiesBudgetPerPerson(
      trip.days,
      travelers,
    );

    _distributePlaces(
      rankedPlaces: rankedPlaces,
      days: days,
      profile: profile,
      dailyActivityBudget: dailyActivityBudget,
      diningPlan: diningDays,
      preference: preference,
    );

    final beforeRouting = days
        .map((day) => List<ScoredPlace>.of(day.places))
        .toList();
    _optimizeDailyRoutes(
      days: days,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );

    // Route optimization must not move the reserved dinner into breakfast.
    for (var index = 0; index < days.length; index++) {
      final activities = days[index].places
          .where((item) => !item.place.isDining)
          .toList();
      days[index].places
        ..clear()
        ..addAll(diningDays[index])
        ..addAll(activities);
    }
    _composeDays(days: days, profile: profile);
    for (var index = 0; index < days.length; index++) {
      if (!_fitsMealWindows(days[index].places)) {
        days[index].places
          ..clear()
          ..addAll(
            compositionService.arrange(
              routeOrderedPlaces: beforeRouting[index],
              profile: profile,
            ),
          );
      }
    }

    final validation = _requireWarningFree(
      validationService.validate(
        days: days,
        rankedPlaces: rankedPlaces,
        profile: profile,
        budgetAllocation: budgetAllocation,
        travelers: travelers,
        currencyCode: currency,
      ),
    );

    return PlannerResult(
      budgetAllocation: budgetAllocation,
      validation: validation,
      profile: profile,
      rankedPlaces: rankedPlaces,
      days: days,
      travelers: travelers,
      currencyCode: currency,
    );
  }

  /// Individual retail businesses are not itinerary attractions. Malls and
  /// department stores are - and a shop that tags itself a mall is still a
  /// shop, which is what [isMajorShoppingPlace] checks.
  ///
  /// A [TravelPlace] carries no primaryType, so this is the weaker type-list
  /// test. It is a second line of defence: the real filtering happens in
  /// DestinationPlaceService, where the Google response is still intact.
  bool _isInvalidRetailCandidate(TravelPlace place) {
    final types = {
      place.category,
      ...place.tags,
    }.map((value) => value.toLowerCase().trim()).toSet();
    if (!isRetailPlace(types)) return false;
    return !isMajorShoppingPlace(types);
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
    int travelers = 1,
    String currencyCode = Money.defaultCurrencyCode,
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
      travelers: travelers,
      currencyCode: currencyCode,
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
    required List<List<ScoredPlace>> diningPlan,
    required Preference preference,
  }) {
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      days[dayIndex].places.addAll(diningPlan[dayIndex]);
    }

    // What the traveler actually asked for goes in first. Scoring alone is not
    // enough: preference is one weighted factor among five, so a shopping trip
    // could fill its days with high-scoring museums before reaching the first
    // mall. Both halves stay in score order, so ranking still decides within
    // each.
    final activityPlaces = <ScoredPlace>[];
    final otherPlaces = <ScoredPlace>[];
    for (final item in rankedPlaces) {
      if (item.place.isDining) continue;
      final wanted = placeScoringService.matchesPreference(
        place: item.place,
        preference: preference,
      );
      (wanted || item.place.destinationHighlight ? activityPlaces : otherPlaces)
          .add(item);
    }
    activityPlaces.addAll(otherPlaces);
    activityPlaces.sort((a, b) {
      final highlight = (b.place.destinationHighlight ? 1 : 0).compareTo(
        a.place.destinationHighlight ? 1 : 0,
      );
      if (highlight != 0) return highlight;
      final preferenceMatch =
          (placeScoringService.matchesPreference(
                    place: b.place,
                    preference: preference,
                  )
                  ? 1
                  : 0)
              .compareTo(
                placeScoringService.matchesPreference(
                      place: a.place,
                      preference: preference,
                    )
                    ? 1
                    : 0,
              );
      return preferenceMatch != 0
          ? preferenceMatch
          : b.totalScore.compareTo(a.totalScore);
    });

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
        final proposed = compositionService.arrange(
          routeOrderedPlaces: [...day.places, scoredPlace],
          profile: profile,
        );
        final withinMealTimes = _fitsMealWindows(proposed);

        if (hasSpace && withinBudget && withinTime && withinMealTimes) {
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

  bool _fitsMealWindows(List<ScoredPlace> places) =>
      const DailyTimeScheduleService()
          .schedule(places)
          .every(
            (stop) =>
                (stop.roleLabel != 'Lunch' || stop.startMinutes <= 14 * 60) &&
                (stop.roleLabel != 'Dinner' || stop.startMinutes <= 20 * 60),
          );
}
