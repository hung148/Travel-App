import 'score_place.dart';

class PlannerDay {
  final int dayNumber;
  final List<ScoredPlace> places;

  const PlannerDay({
    required this.dayNumber,
    required this.places,
  });

  double get estimatedCost {
    return places.fold(
      0,
      (total, item) =>
          total + item.place.estimatedCost,
    );
  }
}

class PlannerResult {
  final List<ScoredPlace> rankedPlaces;
  final List<PlannerDay> days;

  const PlannerResult({
    required this.rankedPlaces,
    required this.days,
  });
}