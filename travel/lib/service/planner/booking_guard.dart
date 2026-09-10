import 'dart:convert';
import '../../models/planner_result.dart';

/// Rejects an AI proposal that drops, duplicates, moves or changes a booking.
bool preservesConfirmedBookings(List<PlannerDay> before, List<PlannerDay> after) {
  for (final day in before) {
    for (final item in day.places.where((item) => item.place.booking?.confirmed == true)) {
      final matches = after.expand((day) => day.places).where((candidate) => candidate.place.id == item.place.id).toList();
      if (matches.length != 1 || !after.any((candidate) => candidate.dayNumber == day.dayNumber &&
          candidate.places.any((place) => place.place.id == item.place.id))) return false;
      if (jsonEncode(matches.single.place.toMap()) != jsonEncode(item.place.toMap())) return false;
    }
  }
  return true;
}
