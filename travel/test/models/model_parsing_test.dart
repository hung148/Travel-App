import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/community/destination_review.dart';
import 'package:travel/models/community/destination_tip.dart';
import 'package:travel/models/feedback.dart' as model;
import 'package:travel/models/itinerary.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/user.dart';

void main() {
  group('Firestore model parsing', () {
    test('Trip safely converts timestamps and numeric values', () {
      final start = DateTime.utc(2026, 9, 1);
      final trip = Trip.fromMap({
        'ownerId': 'user-1',
        'destination': 'Tokyo',
        'budget': 1200,
        'days': 4.0,
        'status': 'upcoming',
        'startDate': Timestamp.fromDate(start),
        'endDate': start.add(const Duration(days: 3)),
        'rating': 5.0,
      }, 'trip-1');

      expect(trip.budget, 1200.0);
      expect(trip.days, 4);
      expect(
        trip.startDate?.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
      );
      expect(
        trip.endDate?.millisecondsSinceEpoch,
        start.add(const Duration(days: 3)).millisecondsSinceEpoch,
      );
      expect(trip.rating, 5);
    });

    test('Itinerary and feedback tolerate missing optional data', () {
      final itinerary = Itinerary.fromMap({'dayNumber': 1.0}, 'day-1');
      final feedback = model.Feedback.fromMap({}, 'feedback-1');

      expect(itinerary.dayNumber, 1);
      expect(itinerary.places, isEmpty);
      expect(itinerary.estimatedCost, 0);
      expect(feedback.rating, 0);
    });

    test('Community reviews and tips parse public destination data safely', () {
      final createdAt = DateTime.utc(2026, 9, 7);
      final review = DestinationReview.fromMap({
        'ownerId': 'user-1',
        'tripId': 'trip-1',
        'destinationName': 'Da Lat, Viet Nam',
        'destinationKey': 'da lat, viet nam',
        'destinationPlaceId': 'place-1',
        'displayName': 'Son',
        'isAnonymous': false,
        'rating': 5.0,
        'tripStyleTags': ['Food', 'Nature'],
        'highlights': ['Coffee'],
        'mustTryFoods': ['banh trang nuong'],
        'recommendedPlaces': ['Xuan Huong Lake'],
        'body': 'A calm city with great coffee and cool weather.',
        'status': 'published',
        'createdAt': Timestamp.fromDate(createdAt),
      }, 'review-1');
      final tip = DestinationTip.fromMap({
        'ownerId': 'user-1',
        'destinationName': 'Da Lat, Viet Nam',
        'destinationKey': 'da lat, viet nam',
        'displayName': 'Traveler',
        'isAnonymous': true,
        'category': 'food',
        'text': 'Try banh trang nuong near the night market.',
        'likesCount': 3.0,
      }, 'tip-1');

      expect(review.visibleName, 'Son');
      expect(review.rating, 5);
      expect(review.mustTryFoods, ['banh trang nuong']);
      expect(
        review.createdAt?.millisecondsSinceEpoch,
        createdAt.millisecondsSinceEpoch,
      );
      expect(tip.visibleName, 'Traveler');
      expect(tip.likesCount, 3);
      expect(
        DestinationReview.normalizeDestinationKey('  Da   Lat, Viet Nam '),
        'da lat, viet nam',
      );
    });
  });

  test(
    'Preference equality and hash code include identity and list contents',
    () {
      Preference make(String ownerId) => Preference(
        id: 'pref-$ownerId',
        ownerId: ownerId,
        experienceType: const ['Nature', 'Food'],
        activityLevel: 'Moderate',
        spendingStyle: 'Normal',
        interests: const ['Coffee'],
      );

      final first = make('user-1');
      final same = make('user-1');
      final otherUser = make('user-2');

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(otherUser));
    },
  );

  test('AppUser copyWith can explicitly clear a profile image', () {
    final user = AppUser(
      uid: 'user-1',
      name: 'Alex',
      email: 'alex@example.com',
      profileImage: 'https://example.com/photo.jpg',
    );

    expect(user.copyWith(profileImage: null).profileImage, isNull);
  });
}
