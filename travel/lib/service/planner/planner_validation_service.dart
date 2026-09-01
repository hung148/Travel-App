import '../../models/budget_allocation.dart';
import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/planner_validation.dart';
import '../../models/place_role.dart';
import '../../models/score_place.dart';
import 'place_role_classifier.dart';

class PlannerValidationService {
  final PlaceRoleClassifier roleClassifier;

  const PlannerValidationService({
    this.roleClassifier = const PlaceRoleClassifier(),
  });

  PlannerValidationResult validate({
    required List<PlannerDay> days,
    required List<ScoredPlace> rankedPlaces,
    required PlannerProfile profile,
    required BudgetAllocation budgetAllocation,
    bool allowUserOverrides = false,
  }) {
    final issues = <PlannerValidationIssue>[];
    final dailyActivityBudget = budgetAllocation.dailyActivitiesBudget(
      days.length,
    );
    final seenPlaceIds = <String>{};
    final constraintSeverity = allowUserOverrides
        ? PlannerValidationSeverity.warning
        : PlannerValidationSeverity.error;

    for (final day in days) {
      for (final scoredPlace in day.places) {
        if (!seenPlaceIds.add(scoredPlace.place.id)) {
          issues.add(
            PlannerValidationIssue(
              code: PlannerValidationCode.duplicatePlace,
              severity: PlannerValidationSeverity.error,
              dayNumber: day.dayNumber,
              message:
                  '${scoredPlace.place.name} appears more than once in the itinerary.',
            ),
          );
        }
      }

      if (day.estimatedCost > dailyActivityBudget + 0.001) {
        issues.add(
          PlannerValidationIssue(
            code: PlannerValidationCode.dailyCostExceeded,
            severity: constraintSeverity,
            dayNumber: day.dayNumber,
            message:
                'Day ${day.dayNumber} exceeds its activity budget of '
                '\$${dailyActivityBudget.toStringAsFixed(0)}.',
          ),
        );
      }

      if (day.estimatedVisitMinutes > profile.targetMinutesPerDay) {
        issues.add(
          PlannerValidationIssue(
            code: PlannerValidationCode.dailyTimeExceeded,
            severity: constraintSeverity,
            dayNumber: day.dayNumber,
            message:
                'Day ${day.dayNumber} exceeds the ${profile.targetMinutesPerDay}-minute target.',
          ),
        );
      }

      if (day.places.length > profile.maxPlacesPerDay) {
        issues.add(
          PlannerValidationIssue(
            code: PlannerValidationCode.dailyPlaceCountExceeded,
            severity: constraintSeverity,
            dayNumber: day.dayNumber,
            message:
                'Day ${day.dayNumber} exceeds the ${profile.maxPlacesPerDay}-place limit.',
          ),
        );
      }

      final diningCount = day.places
          .where(
            (item) => roleClassifier.classify(item.place) == PlaceRole.dining,
          )
          .length;
      if (diningCount > profile.maxDiningPlacesPerDay) {
        issues.add(
          PlannerValidationIssue(
            code: PlannerValidationCode.dailyDiningLimitExceeded,
            severity: constraintSeverity,
            dayNumber: day.dayNumber,
            message:
                'Day ${day.dayNumber} exceeds the ${profile.maxDiningPlacesPerDay}-meal-place limit.',
          ),
        );
      }
    }

    final scheduledIds = days
        .expand((day) => day.places)
        .map((item) => item.place.id)
        .toSet();
    final unscheduledPlaces = rankedPlaces
        .where((item) => !scheduledIds.contains(item.place.id))
        .toList();

    for (final day in days.where((day) => day.places.isNotEmpty)) {
      final isFoodOnly = day.places.every(
        (item) => roleClassifier.classify(item.place) == PlaceRole.dining,
      );
      if (!isFoodOnly) continue;

      final hasNonDiningThatCouldFit = unscheduledPlaces.any(
        (item) =>
            roleClassifier.classify(item.place) != PlaceRole.dining &&
            item.place.estimatedCost <=
                dailyActivityBudget - day.estimatedCost &&
            item.place.estimatedVisitMinutes <=
                profile.targetMinutesPerDay - day.estimatedVisitMinutes &&
            day.places.length < profile.maxPlacesPerDay,
      );
      issues.add(
        PlannerValidationIssue(
          code: hasNonDiningThatCouldFit
              ? PlannerValidationCode.avoidableFoodOnlyDay
              : PlannerValidationCode.unavoidableFoodOnlyDay,
          severity: hasNonDiningThatCouldFit
              ? constraintSeverity
              : PlannerValidationSeverity.warning,
          dayNumber: day.dayNumber,
          message: hasNonDiningThatCouldFit
              ? 'Day ${day.dayNumber} contains only food stops even though another activity fits.'
              : 'Day ${day.dayNumber} contains only food stops because no other activity fits.',
        ),
      );
    }

    for (final day in days.where((day) => day.places.isEmpty)) {
      final hasPlaceThatCouldFit = unscheduledPlaces.any(
        (item) =>
            item.place.estimatedCost <= dailyActivityBudget &&
            item.place.estimatedVisitMinutes <= profile.targetMinutesPerDay,
      );
      issues.add(
        PlannerValidationIssue(
          code: hasPlaceThatCouldFit
              ? PlannerValidationCode.avoidableEmptyDay
              : PlannerValidationCode.unavoidableEmptyDay,
          severity: hasPlaceThatCouldFit
              ? constraintSeverity
              : PlannerValidationSeverity.warning,
          dayNumber: day.dayNumber,
          message: hasPlaceThatCouldFit
              ? 'Day ${day.dayNumber} is empty even though an eligible place is available.'
              : 'Day ${day.dayNumber} is empty because no remaining place fits.',
        ),
      );
    }

    final totalActivityCost = days.fold<double>(
      0,
      (total, day) => total + day.estimatedCost,
    );
    if (totalActivityCost > budgetAllocation.activities + 0.001) {
      issues.add(
        PlannerValidationIssue(
          code: PlannerValidationCode.totalActivityCostExceeded,
          severity: constraintSeverity,
          message: 'Total attraction cost exceeds the activities allocation.',
        ),
      );
    }

    return PlannerValidationResult(issues: issues);
  }
}
