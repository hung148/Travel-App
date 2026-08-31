import 'travel_place.dart';

class ScoredPlace {
  final TravelPlace place;

  final double totalScore;
  final double ratingScore;
  final double reviewScore;
  final double preferenceScore;
  final double budgetScore;
  final double distanceScore;

  const ScoredPlace({
    required this.place,
    required this.totalScore,
    required this.ratingScore,
    required this.reviewScore,
    required this.preferenceScore,
    required this.budgetScore,
    required this.distanceScore,
  });
}