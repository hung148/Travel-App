import '../../models/place_role.dart';
import '../../models/planner_profile.dart';
import '../../models/score_place.dart';
import 'place_role_classifier.dart';

class DailyCompositionService {
  final PlaceRoleClassifier roleClassifier;

  const DailyCompositionService({
    this.roleClassifier = const PlaceRoleClassifier(),
  });

  List<ScoredPlace> arrange({
    required List<ScoredPlace> routeOrderedPlaces,
    required PlannerProfile profile,
  }) {
    final dining = routeOrderedPlaces
        .where(
          (item) => roleClassifier.classify(item.place) == PlaceRole.dining,
        )
        .take(profile.maxDiningPlacesPerDay)
        .toList();
    final nonDining = routeOrderedPlaces
        .where(
          (item) => roleClassifier.classify(item.place) != PlaceRole.dining,
        )
        .toList();

    if (dining.isEmpty) return nonDining;

    final arranged = <ScoredPlace>[dining.first];
    var cursor = 8 * 60 + dining.first.place.estimatedVisitMinutes + 30;
    var lunchAdded = false;
    for (final activity in nonDining) {
      if (!lunchAdded &&
          dining.length > 1 &&
          (cursor >= 12 * 60 ||
              cursor + activity.place.estimatedVisitMinutes + 30 > 14 * 60)) {
        arranged.add(dining[1]);
        cursor =
            (cursor < 12 * 60 ? 12 * 60 : cursor) +
            dining[1].place.estimatedVisitMinutes +
            30;
        lunchAdded = true;
      }
      arranged.add(activity);
      cursor += activity.place.estimatedVisitMinutes + 30;
    }
    if (!lunchAdded && dining.length > 1) arranged.add(dining[1]);
    if (dining.length > 2) arranged.addAll(dining.skip(2));
    return arranged;
  }
}
