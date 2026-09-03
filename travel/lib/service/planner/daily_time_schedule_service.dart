import '../../models/place_role.dart';
import '../../models/scheduled_stop.dart';
import '../../models/score_place.dart';
import 'place_role_classifier.dart';

class DailyTimeScheduleService {
  final PlaceRoleClassifier roleClassifier;
  final int transferMinutes;

  const DailyTimeScheduleService({
    this.roleClassifier = const PlaceRoleClassifier(),
    this.transferMinutes = 30,
  });

  List<ScheduledStop> schedule(
    List<ScoredPlace> places, {
    Map<String, int> startTimeOverrides = const {},
  }) {
    final result = <ScheduledStop>[];
    var cursor = 8 * 60;
    var diningIndex = 0;

    for (final item in places) {
      final role = roleClassifier.classify(item.place);
      late final String label;
      var start = cursor;
      if (role == PlaceRole.dining) {
        label = switch (diningIndex) {
          0 => 'Breakfast',
          1 => 'Lunch',
          2 => 'Dinner',
          final index => 'Extra food stop ${index + 1}',
        };
        start = switch (diningIndex) {
          0 => 8 * 60,
          1 => cursor < 12 * 60 ? 12 * 60 : cursor,
          2 => cursor < 18 * 60 ? 18 * 60 : cursor,
          _ => cursor,
        };
        diningIndex++;
      } else {
        label = role.label;
      }
      start = startTimeOverrides[item.place.id] ?? start;

      result.add(
        ScheduledStop(scoredPlace: item, startMinutes: start, roleLabel: label),
      );
      cursor = start + item.place.estimatedVisitMinutes + transferMinutes;
    }
    return result;
  }
}
