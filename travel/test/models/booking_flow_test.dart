import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/trip/trip_segment.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/ai/itinerary_import_service.dart';
import 'package:travel/service/planner/daily_time_schedule_service.dart';
import 'package:travel/service/trip_clock.dart';
import 'package:travel/widgets/booking_info.dart';

void main() {
  test('existing plan round-trips unknown location, booking and time zone', () {
    final days = ItineraryImportService.draftDays({'items': [{
      'name': 'Airport pickup', 'date': '2026-09-10', 'time': '08:30',
      'reference': 'ABC123', 'address': 'Terminal 2 exit', 'sourceText': 'Airport pickup',
    }]}, start: DateTime(2026, 9, 10), dayCount: 2, zone: 'Asia/Ho_Chi_Minh');
    final trip = Trip(id: 'trip', ownerId: 'user', destination: 'Da Nang', budget: 0, days: 2,
      status: 'draft', segments: [TripSegment(id: 'leg', destination: 'Da Nang',
        startDate: DateTime(2026, 9, 10), endDate: DateTime(2026, 9, 11), allocatedBudget: 0,
        timeZone: 'Asia/Ho_Chi_Minh', days: days)]);
    final restored = Trip.fromMap(trip.toMap(), trip.id);
    final item = restored.segments.single.days.first.places.single.place;
    expect(item.booking!.reference, 'ABC123');
    expect(item.booking!.startMinutes, 510);
    expect(item.hasLocation, isFalse);
    expect(directionsUri(item), isNull);
    expect(restored.segments.single.timeZone, 'Asia/Ho_Chi_Minh');
  });
  test('legacy generated plans keep valid coordinates and unknown booking details', () {
    final item = TravelPlace.fromMap({'name': 'Museum', 'latitude': 10.2, 'longitude': 106.4, 'estimatedCost': 20});
    expect(item.hasLocation, isTrue); expect(item.booking, isNull);
    expect(directionsUri(item)!.queryParameters['destination'], '10.2,106.4');
    expect(item.estimatedCost, 20);
    final day = PlannerDay.fromMap({'dayNumber': 1, 'places': [{'place': item.toMap()}]});
    expect(day.places.single.place.name, 'Museum');
  });
  test('fixed booking time takes priority over planner overrides', () {
    final item = ScoredPlace.fromMap({'place': {'id': 'fixed', 'booking': {'confirmed': true, 'startMinutes': 870}}});
    final schedule = const DailyTimeScheduleService().schedule([item], startTimeOverrides: {'fixed': 480});
    expect(schedule.single.startMinutes, 870);
  });
  test('destination local day crosses midnight and respects daylight saving', () {
    expect(TripClock.dateKey(TripClock.localNow('Asia/Ho_Chi_Minh', now: DateTime.utc(2026, 9, 9, 20))!), '2026-09-10');
    final before = TripClock.localNow('America/New_York', now: DateTime.utc(2026, 3, 8, 6, 59))!;
    final after = TripClock.localNow('America/New_York', now: DateTime.utc(2026, 3, 8, 7, 0))!;
    expect(before.hour, 1); expect(after.hour, 3);
    expect(TripClock.localNow(null), isNull);
    expect(TripClock.parseDate('2026-02-30'), isNull);
  });
  test('missing date and time remain unknown and explicitly flagged', () {
    final days = ItineraryImportService.draftDays({'items': [{'name': 'Flight', 'sourceText': 'Flight'}]},
      start: DateTime(2026, 9, 10), dayCount: 2, zone: 'Asia/Ho_Chi_Minh');
    final booking = days.first.places.single.place.booking!;
    expect(booking.localDate, isNull); expect(booking.startMinutes, isNull);
    expect(booking.warnings, isNotEmpty); expect(booking.confirmed, isFalse);
  });
}
