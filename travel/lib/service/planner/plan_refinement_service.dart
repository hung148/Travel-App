import '../../models/plan_refinement_result.dart';
import '../../models/place_role.dart';
import '../../models/planner_profile.dart';
import '../../models/planner_result.dart';
import '../../models/score_place.dart';
import 'place_role_classifier.dart';
import 'planner_validation_service.dart';
import 'daily_time_schedule_service.dart';

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
      return addFood(currentPlan);
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

  PlanRefinementResult addFood(
    PlannerResult plan, {
    int? dayNumber,
    String? mealType,
  }) {
    final days = _copyDays(plan.days);
    final targets = dayNumber == null
        ? days
        : days.where((day) => day.dayNumber == dayNumber).toList();
    if (targets.isEmpty) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
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

    for (final day in targets) {
      if (!availableFood.moveNext()) break;
      final candidate = availableFood.current;
      day.places.insert(_mealInsertionIndex(day, mealType), candidate);
      scheduledIds.add(candidate.place.id);
      added++;
    }

    return _validated(
      plan,
      days: days,
      changed: added > 0,
      message: added == 0
          ? 'No additional unique food place is available.'
          : dayNumber == null
          ? 'Added $added food ${added == 1 ? 'stop' : 'stops'} across the itinerary as a direct user override.'
          : 'Added one ${mealType ?? 'food stop'} to day $dayNumber as a direct user override.',
    );
  }

  int _mealInsertionIndex(PlannerDay day, String? mealType) {
    final desiredDiningIndex = switch (mealType?.toLowerCase()) {
      'breakfast' => 0,
      'lunch' => 1,
      'dinner' => 2,
      _ => null,
    };
    if (desiredDiningIndex == null) return day.places.length;
    if (desiredDiningIndex == 0) return 0;
    var diningSeen = 0;
    for (var index = 0; index < day.places.length; index++) {
      if (roleClassifier.classify(day.places[index].place) !=
          PlaceRole.dining) {
        continue;
      }
      if (diningSeen == desiredDiningIndex) return index;
      diningSeen++;
    }
    return day.places.length;
  }

  PlanRefinementResult removeStop(PlannerResult plan, String activityName) {
    final match = _findScheduledPlace(plan, activityName);
    if (match == null) return _placeNotFound(plan, activityName);
    final days = _copyDays(plan.days);
    final removed = days[match.dayIndex].places.removeAt(match.stopIndex);
    return _validated(
      plan,
      days: days,
      changed: true,
      message:
          'Removed ${removed.place.name} from day ${days[match.dayIndex].dayNumber} and revalidated the itinerary.',
    );
  }

  PlanRefinementResult removeNumberedStops(
    PlannerResult plan,
    int dayNumber,
    List<int> activityNumbers,
  ) {
    final dayIndex = plan.days.indexWhere((day) => day.dayNumber == dayNumber);
    if (dayIndex < 0) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
    final unique = activityNumbers.toSet().toList()..sort((a, b) => b - a);
    if (unique.isEmpty ||
        unique.any(
          (number) => number < 1 || number > plan.days[dayIndex].places.length,
        )) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Use activity numbers shown on day $dayNumber.',
      );
    }
    final days = _copyDays(plan.days);
    final removedNames = <String>[];
    for (final number in unique) {
      removedNames.add(days[dayIndex].places.removeAt(number - 1).place.name);
    }
    removedNames.sort();
    return _validated(
      plan,
      days: days,
      changed: true,
      message:
          'Removed ${removedNames.join(', ')} from day $dayNumber and revalidated the itinerary.',
    );
  }

  PlanRefinementResult moveStop(
    PlannerResult plan,
    String activityName,
    int targetDayNumber,
  ) {
    final match = _findScheduledPlace(plan, activityName);
    if (match == null) return _placeNotFound(plan, activityName);
    final targetIndex = plan.days.indexWhere(
      (day) => day.dayNumber == targetDayNumber,
    );
    if (targetIndex < 0) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $targetDayNumber does not exist in this itinerary.',
      );
    }
    if (targetIndex == match.dayIndex) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message:
            '${match.place.place.name} is already on day $targetDayNumber.',
      );
    }
    final days = _copyDays(plan.days);
    final moved = days[match.dayIndex].places.removeAt(match.stopIndex);
    days[targetIndex].places.add(moved);
    return _validated(
      plan,
      days: days,
      changed: true,
      message:
          'Moved ${moved.place.name} to day $targetDayNumber and revalidated the itinerary.',
    );
  }

  PlanRefinementResult swapStops(
    PlannerResult plan,
    String firstName,
    String secondName,
  ) {
    final first = _findScheduledPlace(plan, firstName);
    final second = _findScheduledPlace(plan, secondName);
    if (first == null) return _placeNotFound(plan, firstName);
    if (second == null) return _placeNotFound(plan, secondName);
    if (first.dayIndex == second.dayIndex &&
        first.stopIndex == second.stopIndex) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Choose two different stops to swap.',
      );
    }
    final days = _copyDays(plan.days);
    final firstPlace = days[first.dayIndex].places[first.stopIndex];
    final secondPlace = days[second.dayIndex].places[second.stopIndex];
    days[first.dayIndex].places[first.stopIndex] = secondPlace;
    days[second.dayIndex].places[second.stopIndex] = firstPlace;
    final overrides = Map<String, int>.of(plan.startTimeOverrides);
    final firstTime = overrides.remove(firstPlace.place.id);
    final secondTime = overrides.remove(secondPlace.place.id);
    if (secondTime != null) overrides[firstPlace.place.id] = secondTime;
    if (firstTime != null) overrides[secondPlace.place.id] = firstTime;
    return _validated(
      plan,
      days: days,
      changed: true,
      startTimeOverrides: overrides,
      message:
          'Swapped ${firstPlace.place.name} and ${secondPlace.place.name}.',
    );
  }

  PlanRefinementResult replaceWithScheduledStop(
    PlannerResult plan,
    String replacedName,
    String replacementName,
  ) {
    final source = _findScheduledPlace(plan, replacedName);
    final target = _findScheduledPlace(plan, replacementName);
    if (source == null) return _placeNotFound(plan, replacedName);
    if (target == null) return _placeNotFound(plan, replacementName);
    if (source.dayIndex == target.dayIndex &&
        source.stopIndex == target.stopIndex) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Choose two different stops.',
      );
    }
    final days = _copyDays(plan.days);
    final replacement = days[target.dayIndex].places[target.stopIndex];
    days[target.dayIndex].places.removeAt(target.stopIndex);
    var sourceIndex = source.stopIndex;
    if (source.dayIndex == target.dayIndex && target.stopIndex < sourceIndex) {
      sourceIndex--;
    }
    days[source.dayIndex].places[sourceIndex] = replacement;
    final overrides = Map<String, int>.of(plan.startTimeOverrides);
    final sourceTime = overrides.remove(source.place.place.id);
    overrides.remove(replacement.place.id);
    if (sourceTime != null) overrides[replacement.place.id] = sourceTime;
    return _validated(
      plan,
      days: days,
      changed: true,
      startTimeOverrides: overrides,
      message:
          'Replaced $replacedName with $replacementName and removed its old occurrence.',
    );
  }

  PlanRefinementResult moveStopRelative(
    PlannerResult plan,
    String sourceName,
    String targetName,
    String position,
  ) {
    final source = _findScheduledPlace(plan, sourceName);
    final target = _findScheduledPlace(plan, targetName);
    if (source == null) return _placeNotFound(plan, sourceName);
    if (target == null) return _placeNotFound(plan, targetName);
    if (source.place.place.id == target.place.place.id) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Choose a different reference stop.',
      );
    }
    final days = _copyDays(plan.days);
    final moved = days[source.dayIndex].places.removeAt(source.stopIndex);
    var targetIndex = target.stopIndex;
    if (source.dayIndex == target.dayIndex && source.stopIndex < targetIndex) {
      targetIndex--;
    }
    if (position == 'after') targetIndex++;
    days[target.dayIndex].places.insert(targetIndex, moved);
    final overrides = Map<String, int>.of(plan.startTimeOverrides)
      ..remove(moved.place.id);
    return _validated(
      plan,
      days: days,
      changed: true,
      startTimeOverrides: overrides,
      message: 'Moved $sourceName $position $targetName.',
    );
  }

  PlanRefinementResult moveStopToTime(
    PlannerResult plan,
    String sourceName,
    int dayNumber,
    int startMinutes,
  ) {
    if (startMinutes < 6 * 60 || startMinutes >= 24 * 60) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Choose a time between 6:00 AM and 11:59 PM.',
      );
    }
    final source = _findScheduledPlace(plan, sourceName);
    if (source == null) return _placeNotFound(plan, sourceName);
    final targetDayIndex = plan.days.indexWhere(
      (day) => day.dayNumber == dayNumber,
    );
    if (targetDayIndex < 0) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
    final days = _copyDays(plan.days);
    final moved = days[source.dayIndex].places.removeAt(source.stopIndex);
    final targetSchedule = const DailyTimeScheduleService().schedule(
      days[targetDayIndex].places,
      startTimeOverrides: plan.startTimeOverrides,
    );
    var insertionIndex = targetSchedule.indexWhere(
      (stop) => stop.startMinutes >= startMinutes,
    );
    if (insertionIndex < 0) insertionIndex = days[targetDayIndex].places.length;
    days[targetDayIndex].places.insert(insertionIndex, moved);
    final overrides = Map<String, int>.of(plan.startTimeOverrides)
      ..[moved.place.id] = startMinutes;
    final scheduled = const DailyTimeScheduleService().schedule(
      days[targetDayIndex].places,
      startTimeOverrides: overrides,
    );
    for (var index = 1; index < scheduled.length; index++) {
      final previous = scheduled[index - 1];
      if (scheduled[index].startMinutes <
          previous.startMinutes +
              previous.scoredPlace.place.estimatedVisitMinutes +
              30) {
        return PlanRefinementResult(
          plan: plan,
          changed: false,
          message: 'That time overlaps another stop. Choose a later time.',
        );
      }
    }
    return _validated(
      plan,
      days: days,
      changed: true,
      startTimeOverrides: overrides,
      message:
          'Moved $sourceName to day $dayNumber at ${_formatMinutes(startMinutes)}.',
    );
  }

  PlanRefinementResult setDayStartTime(
    PlannerResult plan,
    int dayNumber,
    int startMinutes,
  ) {
    final day = plan.days
        .where((item) => item.dayNumber == dayNumber)
        .firstOrNull;
    if (day == null) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
    if (startMinutes < 6 * 60 || startMinutes >= 24 * 60) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Choose a start time between 6:00 AM and 11:59 PM.',
      );
    }
    var cursor = startMinutes + 30;
    final overrides = Map<String, int>.of(plan.startTimeOverrides);
    for (final place in day.places) {
      overrides[place.place.id] = cursor;
      cursor += place.place.estimatedVisitMinutes + 30;
    }
    if (cursor - 30 > 24 * 60) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message:
            'Starting day $dayNumber at ${_formatMinutes(startMinutes)} would push activities past midnight. Remove stops or choose an earlier time.',
      );
    }
    return _validated(
      plan,
      days: _copyDays(plan.days),
      changed: true,
      startTimeOverrides: overrides,
      message:
          'Rescheduled all stops on day $dayNumber from ${_formatMinutes(startMinutes)} and checked that they fit.',
    );
  }

  PlanRefinementResult addStops(
    PlannerResult plan, {
    int? dayNumber,
    int? requestedCount,
    String? category,
  }) {
    final days = _copyDays(plan.days);
    final targets = dayNumber == null
        ? days
        : days.where((day) => day.dayNumber == dayNumber).toList();
    if (targets.isEmpty) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
    final scheduledIds = days
        .expand((day) => day.places)
        .map((item) => item.place.id)
        .toSet();
    final normalizedCategory = category?.toLowerCase().trim();
    final available = plan.rankedPlaces.where((item) {
      if (scheduledIds.contains(item.place.id) || item.place.isDining) {
        return false;
      }
      if (normalizedCategory == null || normalizedCategory.isEmpty) return true;
      return <String>[
        item.place.name,
        item.place.category,
        ...item.place.tags,
      ].any((value) => value.toLowerCase().contains(normalizedCategory));
    }).toList()..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final wanted = requestedCount ?? 1000000;
    var added = 0;
    var targetIndex = 0;
    for (final candidate in available) {
      if (added >= wanted) break;
      var inserted = false;
      for (var attempt = 0; attempt < targets.length; attempt++) {
        final day = targets[(targetIndex + attempt) % targets.length];
        final dailyActivityBudget = plan.budgetAllocation.dailyActivitiesBudget(
          days.length,
        );
        if (day.activityCount >= plan.profile.maxPlacesPerDay ||
            day.estimatedActivityMinutes +
                    candidate.place.estimatedVisitMinutes >
                plan.profile.targetMinutesPerDay ||
            day.estimatedActivityCost + candidate.place.estimatedCost >
                dailyActivityBudget + 0.001) {
          continue;
        }
        day.places.add(candidate);
        scheduledIds.add(candidate.place.id);
        added++;
        targetIndex = (targetIndex + attempt + 1) % targets.length;
        inserted = true;
        break;
      }
      if (!inserted &&
          targets.every(
            (day) => day.activityCount >= plan.profile.maxPlacesPerDay,
          )) {
        break;
      }
    }
    final requestedText = requestedCount == null
        ? 'as many safe stops as possible'
        : '$requestedCount stops';
    return _validated(
      plan,
      days: days,
      changed: added > 0,
      message: added == 0
          ? 'No unused ${category ?? 'activity'} stops fit the remaining time and budget.'
          : 'Requested $requestedText and safely added $added${dayNumber == null ? ' across the itinerary' : ' to day $dayNumber'}.',
    );
  }

  PlanRefinementResult removeStops(
    PlannerResult plan, {
    int? dayNumber,
    required int count,
    String? category,
  }) {
    final days = _copyDays(plan.days);
    final targets = dayNumber == null
        ? days
        : days.where((day) => day.dayNumber == dayNumber).toList();
    if (targets.isEmpty) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: 'Day $dayNumber does not exist in this itinerary.',
      );
    }
    final normalizedCategory = category?.toLowerCase().trim();
    final candidates = <({PlannerDay day, ScoredPlace place})>[];
    for (final day in targets) {
      for (final place in day.places.where((item) => !item.place.isDining)) {
        if (normalizedCategory != null &&
            normalizedCategory.isNotEmpty &&
            !<String>[
              place.place.name,
              place.place.category,
              ...place.place.tags,
            ].any(
              (value) => value.toLowerCase().contains(normalizedCategory),
            )) {
          continue;
        }
        candidates.add((day: day, place: place));
      }
    }
    candidates.sort((a, b) => a.place.totalScore.compareTo(b.place.totalScore));
    final removed = candidates.take(count).toList();
    for (final item in removed) {
      item.day.places.removeWhere(
        (place) => place.place.id == item.place.place.id,
      );
    }
    final overrides = Map<String, int>.of(plan.startTimeOverrides);
    for (final item in removed) {
      overrides.remove(item.place.place.id);
    }
    return _validated(
      plan,
      days: days,
      changed: removed.isNotEmpty,
      startTimeOverrides: overrides,
      message: removed.isEmpty
          ? 'No matching optional activities were available to remove.'
          : 'Requested $count stops and removed ${removed.length} lowest-priority matching activities${dayNumber == null ? '' : ' from day $dayNumber'}.',
    );
  }

  String _formatMinutes(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  PlanRefinementResult replaceStop(
    PlannerResult plan,
    String activityName, {
    String? replacementPreference,
    String? replacementCriterion,
  }) {
    final match = _findScheduledPlace(plan, activityName);
    if (match == null) return _placeNotFound(plan, activityName);
    final scheduledIds = plan.days
        .expand((day) => day.places)
        .map((item) => item.place.id)
        .toSet();
    final preference = replacementPreference?.toLowerCase().trim();
    final candidates = plan.rankedPlaces.where((candidate) {
      if (scheduledIds.contains(candidate.place.id)) return false;
      if (candidate.place.isDining != match.place.place.isDining) return false;
      if (preference == null || preference.isEmpty) return true;
      return <String>[
        candidate.place.name,
        candidate.place.category,
        ...candidate.place.tags,
      ].any((value) => value.toLowerCase().contains(preference));
    }).toList();
    if (candidates.isEmpty) {
      return PlanRefinementResult(
        plan: plan,
        changed: false,
        message: preference == null || preference.isEmpty
            ? 'No unused replacement is available for ${match.place.place.name}.'
            : 'No unused $replacementPreference replacement is available for ${match.place.place.name}.',
      );
    }
    candidates.sort(
      (a, b) => switch (replacementCriterion) {
        'closer' => b.distanceScore.compareTo(a.distanceScore),
        'cheaper' => a.place.estimatedCost.compareTo(b.place.estimatedCost),
        'higher_rated' => b.place.rating.compareTo(a.place.rating),
        'more_popular' => b.place.reviewCount.compareTo(a.place.reviewCount),
        _ => b.totalScore.compareTo(a.totalScore),
      },
    );
    final replacement = candidates.first;
    final days = _copyDays(plan.days);
    days[match.dayIndex].places[match.stopIndex] = replacement;
    return _validated(
      plan,
      days: days,
      changed: true,
      message:
          'Replaced ${match.place.place.name} with ${replacement.place.name} on day ${days[match.dayIndex].dayNumber} using ${_replacementReason(replacementCriterion, replacementPreference)}.',
    );
  }

  String _replacementReason(String? criterion, String? preference) {
    if (preference != null && preference.trim().isNotEmpty) {
      return 'the requested “$preference” category and best planner score';
    }
    return switch (criterion) {
      'closer' => 'the strongest distance score',
      'cheaper' => 'the lowest estimated cost',
      'higher_rated' => 'the highest Google rating',
      'more_popular' => 'the largest review count',
      _ => 'the best overall planner score',
    };
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
      while (day.activityCount > PlannerProfile.relaxed.maxPlacesPerDay ||
          day.estimatedActivityMinutes >
              PlannerProfile.relaxed.targetMinutesPerDay) {
        int? removableIndex;
        for (var index = 0; index < day.places.length; index++) {
          final candidate = day.places[index];
          if (roleClassifier.classify(candidate.place) == PlaceRole.dining) {
            continue;
          }
          if (removableIndex == null ||
              candidate.totalScore < day.places[removableIndex].totalScore) {
            removableIndex = index;
          }
        }
        if (removableIndex == null) break;
        day.places.removeAt(removableIndex);
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
    Map<String, int>? startTimeOverrides,
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
      startTimeOverrides: startTimeOverrides ?? original.startTimeOverrides,
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

  _ScheduledPlaceMatch? _findScheduledPlace(
    PlannerResult plan,
    String activityName,
  ) {
    final query = activityName.toLowerCase().trim();
    if (query.isEmpty) return null;
    final matches = <_ScheduledPlaceMatch>[];
    for (var dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
      for (
        var stopIndex = 0;
        stopIndex < plan.days[dayIndex].places.length;
        stopIndex++
      ) {
        final place = plan.days[dayIndex].places[stopIndex];
        final name = place.place.name.toLowerCase();
        if (name == query) {
          return _ScheduledPlaceMatch(dayIndex, stopIndex, place);
        }
        if (name.contains(query) || query.contains(name)) {
          matches.add(_ScheduledPlaceMatch(dayIndex, stopIndex, place));
        }
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  PlanRefinementResult _placeNotFound(
    PlannerResult plan,
    String activityName,
  ) => PlanRefinementResult(
    plan: plan,
    changed: false,
    message:
        'I could not uniquely find “$activityName” in this itinerary. Use the activity name shown in the plan.',
  );

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

class _ScheduledPlaceMatch {
  const _ScheduledPlaceMatch(this.dayIndex, this.stopIndex, this.place);

  final int dayIndex;
  final int stopIndex;
  final ScoredPlace place;
}
