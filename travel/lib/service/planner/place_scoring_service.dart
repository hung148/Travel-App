import 'dart:math';

import '../../models/preference/preferences.dart';
import '../../models/planner_profile.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import 'preference_normalizer.dart';
import 'place_role_classifier.dart';

class PlaceScoringService {
  final PreferenceNormalizer preferenceNormalizer;
  final PlaceRoleClassifier roleClassifier;

  const PlaceScoringService({
    this.preferenceNormalizer = const PreferenceNormalizer(),
    this.roleClassifier = const PlaceRoleClassifier(),
  });

  ScoredPlace scorePlace({
    required TravelPlace place,
    required Preference preference,
    required double dailyActivityBudget,
    required double centerLatitude,
    required double centerLongitude,
    required PlannerProfile profile,
  }) {
    final rating = _ratingScore(place.rating);

    final reviews = _reviewScore(place.reviewCount);

    final preferenceMatch = _preferenceScore(
      place: place,
      preference: preference,
    );

    final budget = _budgetScore(
      placeCost: place.estimatedCost,
      dailyActivityBudget: dailyActivityBudget,
    );

    final distanceKm = _calculateDistanceKm(
      startLat: centerLatitude,
      startLng: centerLongitude,
      endLat: place.latitude,
      endLng: place.longitude,
    );

    final distance = _distanceScore(
      distanceKm: distanceKm,
      toleranceKm: profile.distanceToleranceKm,
    );

    final weights = profile.scoringWeights;
    final total =
        rating * weights.rating +
        reviews * weights.reviews +
        preferenceMatch * weights.preference +
        budget * weights.budget +
        distance * weights.distance;

    return ScoredPlace(
      place: place,
      totalScore: total,
      ratingScore: rating,
      reviewScore: reviews,
      preferenceScore: preferenceMatch,
      budgetScore: budget,
      distanceScore: distance,
    );
  }

  List<ScoredPlace> rankPlaces({
    required List<TravelPlace> places,
    required Preference preference,
    required double dailyActivityBudget,
    required double centerLatitude,
    required double centerLongitude,
    required PlannerProfile profile,
  }) {
    final scored = places.map((place) {
      return scorePlace(
        place: place,
        preference: preference,
        dailyActivityBudget: dailyActivityBudget,
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        profile: profile,
      );
    }).toList();

    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return scored;
  }

  double _ratingScore(double rating) {
    return ((rating / 5.0) * 100).clamp(0, 100).toDouble();
  }

  double _reviewScore(int reviewCount) {
    if (reviewCount <= 0) {
      return 0;
    }

    const maxUsefulReviews = 10000;

    final score = log(reviewCount + 1) / log(maxUsefulReviews + 1) * 100;

    return score.clamp(0, 100).toDouble();
  }

  double _preferenceScore({
    required TravelPlace place,
    required Preference preference,
  }) {
    final userPreferences =
        <String>[...preference.experienceType, ...preference.interests]
            .map(preferenceNormalizer.normalize)
            .where((item) => item.isNotEmpty)
            .toSet();

    if (userPreferences.isEmpty) {
      return 50;
    }

    final role = roleClassifier.classify(place);
    final placeTags = preferenceNormalizer.expandAll([
      place.category,
      ...place.tags,
      ...roleClassifier.preferenceTerms(role),
    ]);

    int matches = 0;

    for (final userPreference in userPreferences) {
      final preferenceTerms = preferenceNormalizer.expand(userPreference);
      if (preferenceTerms.any(placeTags.contains)) {
        matches++;
      }
    }

    if (matches == 0) {
      return 20;
    }

    final score = matches / userPreferences.length * 100;

    // Give at least a reasonable score when there is
    // a genuine preference match.
    return max(45, score).clamp(0, 100).toDouble();
  }

  double _budgetScore({
    required double placeCost,
    required double dailyActivityBudget,
  }) {
    if (dailyActivityBudget <= 0) {
      return 50;
    }

    if (placeCost <= 0) {
      return 100;
    }

    final ratio = placeCost / dailyActivityBudget;

    if (ratio <= 0.20) {
      return 100;
    }

    if (ratio <= 0.35) {
      return 90;
    }

    if (ratio <= 0.50) {
      return 75;
    }

    if (ratio <= 0.75) {
      return 55;
    }

    if (ratio <= 1.0) {
      return 35;
    }

    return 10;
  }

  double _distanceScore({
    required double distanceKm,
    required double toleranceKm,
  }) {
    final distanceRatio = distanceKm / toleranceKm;

    if (distanceRatio <= 0.25) {
      return 100;
    }

    if (distanceRatio <= 0.50) {
      return 85;
    }

    if (distanceRatio <= 0.75) {
      return 65;
    }

    if (distanceRatio <= 1.0) {
      return 40;
    }

    return 20;
  }

  double _calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);

    final a =
        pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            pow(sin(dLng / 2), 2);

    final c = 2 * atan2(sqrt(a.toDouble()), sqrt((1 - a).toDouble()));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
