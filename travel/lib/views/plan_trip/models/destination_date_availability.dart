import 'package:flutter/material.dart';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isDateUnavailable(DateTime day, List<DateTimeRange> unavailableRanges) {
  final value = _dateOnly(day);
  return unavailableRanges.any((range) {
    final start = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    return !value.isBefore(start) && !value.isAfter(end);
  });
}

bool dateRangeOverlaps(
  DateTimeRange candidate,
  List<DateTimeRange> unavailableRanges,
) {
  final candidateStart = _dateOnly(candidate.start);
  final candidateEnd = _dateOnly(candidate.end);
  return unavailableRanges.any((range) {
    final start = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    return !candidateEnd.isBefore(start) && !candidateStart.isAfter(end);
  });
}

DateTimeRange? transitDateRange(DateTime previousEnd, int transitDays) {
  if (transitDays <= 0) return null;
  final start = _dateOnly(previousEnd).add(const Duration(days: 1));
  return DateTimeRange(
    start: start,
    end: start.add(Duration(days: transitDays - 1)),
  );
}
