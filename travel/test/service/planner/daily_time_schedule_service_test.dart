import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/planner/daily_time_schedule_service.dart';

void main() {
  test('assigns breakfast, lunch, dinner, and detailed start times', () {
    final schedule = const DailyTimeScheduleService().schedule([
      _place('breakfast', 'cafe', 45),
      _place('museum', 'museum', 120),
      _place('lunch', 'restaurant', 60),
      _place('park', 'park', 90),
      _place('dinner', 'sushi_restaurant', 75),
    ]);

    expect(schedule.map((stop) => stop.roleLabel), [
      'Breakfast',
      'Culture',
      'Lunch',
      'Nature',
      'Dinner',
    ]);
    expect(schedule.first.formattedStartTime, '8:00 AM');
    expect(schedule[2].startMinutes, greaterThanOrEqualTo(12 * 60));
    expect(schedule.last.startMinutes, greaterThanOrEqualTo(18 * 60));
  });
}

ScoredPlace _place(String id, String category, int minutes) => ScoredPlace(
  place: TravelPlace(
    id: id,
    name: id,
    category: category,
    tags: [category],
    rating: 4.5,
    reviewCount: 100,
    estimatedCost: 15,
    latitude: 0,
    longitude: 0,
    estimatedVisitMinutes: minutes,
  ),
  totalScore: 80,
  ratingScore: 80,
  reviewScore: 80,
  preferenceScore: 80,
  budgetScore: 80,
  distanceScore: 80,
);
