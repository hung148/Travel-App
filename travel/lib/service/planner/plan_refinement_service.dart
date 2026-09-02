import '../../models/plan_refinement_result.dart';
import '../../models/place_role.dart';
import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/score_place.dart';
import 'place_role_classifier.dart';
import 'planner_validation_service.dart';

class PlanRefinementService {
  final PlaceRoleClassifier roleClassifier;
  final PlannerValidationService validationService;

  const PlanRefinementService({
    this.roleClassifier = const PlaceRoleClassifier(),
    this.validationService = const PlannerValidationService(),
  });

  PlanRefinementResult refine({
    required PlannerResult currentPlan,
    required String instruction,
  }) {
    final text = instruction.toLowerCase().trim();
    if (text.contains('remove museum') || text.contains('no museum')) {
      return _removeMuseums(currentPlan);
    }
    if (text.contains('more food') || text.contains('add food')) {
      return _addFood(currentPlan);
    }
    if (text.contains('relax') || text.contains('calm')) {
      return _relaxDay(currentPlan, _dayNumber(text));
    }
    if (text.contains('walk') || text.contains('travel time')) {
      return PlanRefinementResult(
        plan: currentPlan,
        changed: false,
        message:
            'This plan is already ordered by nearest-neighbor distance within each day. No safe change was needed.',
      );
    }
    return PlanRefinementResult(
      plan: currentPlan,
      changed: false,
      message:
          'I could not safely apply that yet. Try “make day 2 more relaxing”, “add more food”, “remove museums”, or “less walking”.',
    );
  }

  PlanRefinementResult _removeMuseums(PlannerResult plan) {
    var removed = 0;
    final ranked = plan.rankedPlaces.where((item) {
      return !_isMuseum(item);
    }).toList();
    final days = plan.days.map((day) {
      final places = day.places.where((item) {
        final keep = !_isMuseum(item);
        if (!keep) removed++;
        return keep;
      }).toList();
      return PlannerDay(dayNumber: day.dayNumber, places: places);
    }).toList();
    return _validated(
      plan,
      days: days,
      rankedPlaces: ranked,
      changed: removed > 0,
      message: removed == 0
          ? 'There were no museums in the current itinerary.'
          : 'Removed $removed museum ${removed == 1 ? 'stop' : 'stops'} and revalidated the itinerary.',
    );
  }

  PlanRefinementResult _addFood(PlannerResult plan) {
    final days = _copyDays(plan.days);
    final scheduledIds = days
        .expand((day) => day.places)
        .map((item) => item.place.id)
        .toSet();
    final availableFood = plan.rankedPlaces
        .where(
          (item) =>
              !scheduledIds.contains(item.place.id) &&
              roleClassifier.classify(item.place) == PlaceRole.dining,
        )
        .iterator;
    var added = 0;

    for (final day in days) {
      if (!availableFood.moveNext()) break;
      final candidate = availableFood.current;
      day.places.add(candidate);
      scheduledIds.add(candidate.place.id);
      added++;
    }

    return _validated(
      plan,
      days: days,
      changed: added > 0,
      message: added == 0
          ? 'No additional unique food place is available.'
          : 'Added $added food ${added == 1 ? 'stop' : 'stops'} as a direct user override.',
    );
  }

  PlanRefinementResult _relaxDay(PlannerResult plan, int? requestedDay) {
    final days = _copyDays(plan.days);
    final targets = requestedDay == null
        ? days
        : days.where((day) => day.dayNumber == requestedDay).toList();
    if (targets.isEmpty) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $requestedDay does not exist in this itinerary.',
      );
    }

    var removed = 0;
    for (final day in targets) {
      while (day.places.length > PlannerProfile.relaxed.maxPlacesPerDay ||
          day.estimatedVisitMinutes >
              PlannerProfile.relaxed.targetMinutesPerDay) {
        day.places.removeLast();
        removed++;
      }
    }
    return _validated(
      plan,
      days: days,
      changed: removed > 0,
      message: removed == 0
          ? '${requestedDay == null ? 'The schedule is' : 'Day $requestedDay is'} already within relaxed limits.'
          : 'Removed $removed lower-priority ${removed == 1 ? 'stop' : 'stops'} from ${requestedDay == null ? 'the itinerary' : 'day $requestedDay'} and revalidated it.',
    );
  }

  PlanRefinementResult _validated(
    PlannerResult original, {
    required List<PlannerDay> days,
    List<ScoredPlace>? rankedPlaces,
    required bool changed,
    required String message,
  }) {
    final ranked = rankedPlaces ?? original.rankedPlaces;
    final validation = validationService.validate(
      days: days,
      rankedPlaces: ranked,
      profile: original.profile,
      budgetAllocation: original.budgetAllocation,
      allowUserOverrides: true,
    );
    final result = PlannerResult(
      budgetAllocation: original.budgetAllocation,
      validation: validation,
      profile: original.profile,
      rankedPlaces: ranked,
      days: days,
      hotel: original.hotel,
    );
    return PlanRefinementResult(
      plan: result,
      changed: changed,
      message: validation.isValid
          ? validation.warnings.isEmpty
                ? '$message Validation passed.'
                : '$message Applied with ${validation.warnings.length} user-override ${validation.warnings.length == 1 ? 'warning' : 'warnings'}.'
          : '$message The change was rejected because validation failed.',
    );
  }

  bool _isMuseum(ScoredPlace item) {
    final values = {item.place.category, ...item.place.tags};
    return values.any((value) => value.toLowerCase().contains('museum'));
  }

  int? _dayNumber(String text) {
    final match = RegExp(r'day\s+(\d+)').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  List<PlannerDay> _copyDays(List<PlannerDay> days) => days
      .map(
        (day) => PlannerDay(
          dayNumber: day.dayNumber,
          places: List<ScoredPlace>.of(day.places),
        ),
      )
      .toList();
}
