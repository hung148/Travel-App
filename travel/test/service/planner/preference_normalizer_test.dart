import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/planner_profile.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/preference_normalizer.dart';

void main() {
  const normalizer = PreferenceNormalizer();

  group('PreferenceNormalizer', () {
    test('normalizes case, spaces, and punctuation', () {
      expect(normalizer.normalize('  Art Gallery  '), 'art_gallery');
      expect(normalizer.normalize('Shopping-Mall'), 'shopping_mall');
    });

    test('expands the supported preference synonyms', () {
      expect(normalizer.expand('Coffee'), containsAll(['cafe', 'food']));
      expect(
        normalizer.expand('Local food'),
        containsAll(['food', 'restaurant', 'dining']),
      );
      expect(
        normalizer.expand('Museums'),
        containsAll(['museum', 'art_gallery']),
      );
      expect(normalizer.expand('Beach'), contains('nature'));
      expect(
        normalizer.expand('Shopping'),
        containsAll(['shopping_mall', 'store']),
      );
      expect(
        normalizer.expand('History'),
        containsAll(['museum', 'shrine', 'temple', 'historic']),
      );
    });
  });

  group('PlaceScoringService preference synonyms', () {
    final scoringService = PlaceScoringService();

    for (final testCase in <({String preference, String category})>[
      (preference: 'coffee', category: 'cafe'),
      (preference: 'museums', category: 'art_gallery'),
      (preference: 'beach', category: 'nature'),
      (preference: 'shopping', category: 'shopping_mall'),
      (preference: 'history', category: 'temple'),
      (preference: 'local food', category: 'ramen_restaurant'),
      (preference: 'nature', category: 'park'),
      (preference: 'entertainment', category: 'bowling_alley'),
    ]) {
      test('${testCase.preference} matches ${testCase.category}', () {
        final score = scoringService.scorePlace(
          place: _place(testCase.category),
          preference: _preference(testCase.preference),
          dailyActivityBudget: 100,
          centerLatitude: 0,
          centerLongitude: 0,
          profile: PlannerProfile.balanced,
        );

        expect(score.preferenceScore, 100);
      });
    }

    test('an unrelated place retains the non-match score', () {
      final score = scoringService.scorePlace(
        place: _place('stadium'),
        preference: _preference('coffee'),
        dailyActivityBudget: 100,
        centerLatitude: 0,
        centerLongitude: 0,
        profile: PlannerProfile.balanced,
      );

      expect(score.preferenceScore, 20);
    });

    test(
      'preferred role ranks above an otherwise identical unrelated role',
      () {
        final preference = _preference('nature');
        final preferred = scoringService.scorePlace(
          place: _place('park'),
          preference: preference,
          dailyActivityBudget: 100,
          centerLatitude: 0,
          centerLongitude: 0,
          profile: PlannerProfile.balanced,
        );
        final unrelated = scoringService.scorePlace(
          place: _place('shopping_mall'),
          preference: preference,
          dailyActivityBudget: 100,
          centerLatitude: 0,
          centerLongitude: 0,
          profile: PlannerProfile.balanced,
        );

        expect(
          preferred.preferenceScore,
          greaterThan(unrelated.preferenceScore),
        );
        expect(preferred.totalScore, greaterThan(unrelated.totalScore));
      },
    );
  });
}

Preference _preference(String interest) {
  return Preference(
    id: 'preference',
    ownerId: 'user',
    experienceType: const [],
    activityLevel: 'Moderate',
    spendingStyle: 'Normal',
    interests: [interest],
  );
}

TravelPlace _place(String category) {
  return TravelPlace(
    id: category,
    name: category,
    category: category,
    tags: const [],
    rating: 4,
    reviewCount: 100,
    estimatedCost: 10,
    latitude: 0,
    longitude: 0,
    estimatedVisitMinutes: 60,
  );
}
