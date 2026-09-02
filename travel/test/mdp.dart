import 'package:flutter_test/flutter_test.dart';

import 'package:travel/models/hotel_selections.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/trip/trip_segment.dart';

void main() {
  test('multi-destination trip survives map round trip', () {
    const breakfast = TravelPlace(
      id: 'breakfast-1',
      name: 'Da Nang Breakfast',
      category: 'restaurant',
      tags: ['breakfast'],
      rating: 4.7,
      reviewCount: 800,
      estimatedCost: 12,
      latitude: 16.05,
      longitude: 108.20,
      estimatedVisitMinutes: 60,
    );

    const attraction = TravelPlace(
      id: 'attraction-1',
      name: 'Da Nang Attraction',
      category: 'tourist_attraction',
      tags: ['culture'],
      rating: 4.8,
      reviewCount: 1200,
      estimatedCost: 20,
      latitude: 16.06,
      longitude: 108.21,
      estimatedVisitMinutes: 90,
    );

    const scoredBreakfast = ScoredPlace(
      place: breakfast,
      totalScore: 90,
      ratingScore: 20,
      reviewScore: 20,
      preferenceScore: 20,
      budgetScore: 15,
      distanceScore: 15,
    );

    const scoredAttraction = ScoredPlace(
      place: attraction,
      totalScore: 88,
      ratingScore: 20,
      reviewScore: 20,
      preferenceScore: 18,
      budgetScore: 15,
      distanceScore: 15,
    );

    const day1 = PlannerDay(
      dayNumber: 1,
      places: [scoredBreakfast, scoredAttraction],
    );

    const daNangHotel = HotelSelection(
      placeId: 'hotel-da-nang',
      name: 'Da Nang Hotel',
      address: 'Da Nang, Vietnam',
      nightlyPrice: 80,
      nights: 2,
    );

    const hcmHotel = HotelSelection(
      placeId: 'hotel-hcm',
      name: 'HCM Hotel',
      address: 'Ho Chi Minh City, Vietnam',
      nightlyPrice: 120,
      nights: 2,
    );

    final original = Trip(
      id: 'trip-1',
      ownerId: 'user-1',
      destination: 'Vietnam',
      budget: 2000,
      days: 5,
      status: 'draft',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 14),
      segments: [
        TripSegment(
          id: 'da-nang',
          destination: 'Da Nang',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 11),
          allocatedBudget: 800,
          hotel: daNangHotel,
          days: const [day1],
          scheduleSaved: true,
        ),
        TripSegment(
          id: 'hcm',
          destination: 'Ho Chi Minh City',
          startDate: DateTime(2026, 9, 12),
          endDate: DateTime(2026, 9, 14),
          allocatedBudget: 1000,
          hotel: hcmHotel,
          scheduleSaved: true,
        ),
      ],
    );

    final map = original.toMap();
    final restored = Trip.fromMap(map, original.id);

    expect(restored.segments.length, 2);

    expect(restored.segments[0].destination, 'Da Nang');
    expect(restored.segments[1].destination, 'Ho Chi Minh City');

    expect(restored.segments[0].hotel?.name, 'Da Nang Hotel');
    expect(restored.segments[1].hotel?.name, 'HCM Hotel');

    expect(restored.segments[0].scheduleSaved, true);
    expect(restored.segments[1].scheduleSaved, true);

    expect(restored.segments[0].days.length, 1);
    expect(restored.segments[0].days.first.places.length, 2);

    expect(
      restored.segments[0].days.first.places.first.place.name,
      'Da Nang Breakfast',
    );

    expect(restored.totalHotelCost, 400);
    expect(restored.totalFoodCost, 12);
    expect(restored.totalActivityCost, 20);
    expect(restored.estimatedSegmentsCost, 432);
  });
}
