import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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
