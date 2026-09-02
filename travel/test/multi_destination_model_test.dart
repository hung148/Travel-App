import 'package:flutter_test/flutter_test.dart';

import 'package:travel/models/hotel_selections.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/trip/trip_segment.dart';

void main() {
  test('trip supports multiple destinations with different hotels', () {
    final daNangHotel = HotelSelection(
      placeId: 'hotel-da-nang',
      name: 'Da Nang Hotel',
      address: 'Da Nang, Vietnam',
      latitude: 16.0544,
      longitude: 108.2022,
      nightlyPrice: 80,
      nights: 3,
    );

    final hcmHotel = HotelSelection(
      placeId: 'hotel-hcm',
      name: 'HCM Hotel',
      address: 'Ho Chi Minh City, Vietnam',
      latitude: 10.7769,
      longitude: 106.7009,
      nightlyPrice: 120,
      nights: 3,
    );

    final daNang = TripSegment(
      id: 'segment-da-nang',
      destination: 'Da Nang',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
      allocatedBudget: 800,
      hotel: daNangHotel,
    );

    final hcm = TripSegment(
      id: 'segment-hcm',
      destination: 'Ho Chi Minh City',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 15),
      allocatedBudget: 1000,
      hotel: hcmHotel,
    );

    final trip = Trip(
      id: 'test-trip',
      ownerId: 'test-user',
      destination: 'Vietnam',
      budget: 2000,
      days: 6,
      status: 'draft',
      segments: [
        daNang,
        hcm,
      ],
    );

    expect(trip.destinationCount, 2);

    expect(
      trip.segments[0].destination,
      'Da Nang',
    );

    expect(
      trip.segments[1].destination,
      'Ho Chi Minh City',
    );

    expect(
      trip.segments[0].hotel?.name,
      'Da Nang Hotel',
    );

    expect(
      trip.segments[1].hotel?.name,
      'HCM Hotel',
    );

    expect(
      trip.segments[0].hotelCost,
      240,
    );

    expect(
      trip.segments[1].hotelCost,
      360,
    );

    expect(
      trip.allocatedSegmentBudget,
      1800,
    );
  });
}