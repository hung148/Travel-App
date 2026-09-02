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

  Map<String, dynamic> toMap() {
    return {
      'place': place.toMap(),
      'totalScore': totalScore,
      'ratingScore': ratingScore,
      'reviewScore': reviewScore,
      'preferenceScore': preferenceScore,
      'budgetScore': budgetScore,
      'distanceScore': distanceScore,
    };
  }

  factory ScoredPlace.fromMap(Map<String, dynamic> data) {
    final placeData = Map<String, dynamic>.from(
      data['place'] as Map? ?? const <String, dynamic>{},
    );

    return ScoredPlace(
      place: TravelPlace.fromMap(placeData),
      totalScore: (data['totalScore'] as num?)?.toDouble() ?? 0,
      ratingScore: (data['ratingScore'] as num?)?.toDouble() ?? 0,
      reviewScore: (data['reviewScore'] as num?)?.toDouble() ?? 0,
      preferenceScore: (data['preferenceScore'] as num?)?.toDouble() ?? 0,
      budgetScore: (data['budgetScore'] as num?)?.toDouble() ?? 0,
      distanceScore: (data['distanceScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
