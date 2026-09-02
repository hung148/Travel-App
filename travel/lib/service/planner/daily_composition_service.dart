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
    final lunchIndex = (nonDining.length / 2).ceil();
    arranged.addAll(nonDining.take(lunchIndex));
    if (dining.length > 1) arranged.add(dining[1]);
    arranged.addAll(nonDining.skip(lunchIndex));
    if (dining.length > 2) arranged.addAll(dining.skip(2));
    return arranged;
  }
}
