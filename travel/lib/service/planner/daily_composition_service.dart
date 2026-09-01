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

    if (dining.isEmpty || nonDining.isEmpty) return [...nonDining, ...dining];

    final arranged = List<ScoredPlace>.of(nonDining);
    arranged.insert(arranged.length > 1 ? 1 : arranged.length, dining.first);
    if (dining.length > 1) arranged.addAll(dining.skip(1));
    return arranged;
  }
}
