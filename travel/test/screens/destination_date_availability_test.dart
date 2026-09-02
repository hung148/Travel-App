import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/views/plan_trip/models/destination_date_availability.dart';

void main() {
  final occupied = [
    DateTimeRange(start: DateTime(2026, 9, 10), end: DateTime(2026, 9, 14)),
  ];

  test('occupied destination dates are unavailable inclusively', () {
    expect(isDateUnavailable(DateTime(2026, 9, 9), occupied), isFalse);
    expect(isDateUnavailable(DateTime(2026, 9, 10), occupied), isTrue);
    expect(isDateUnavailable(DateTime(2026, 9, 12), occupied), isTrue);
    expect(isDateUnavailable(DateTime(2026, 9, 14), occupied), isTrue);
    expect(isDateUnavailable(DateTime(2026, 9, 15), occupied), isFalse);
  });

  test('ranges cannot cross or touch an occupied destination date', () {
    expect(
      dateRangeOverlaps(
        DateTimeRange(start: DateTime(2026, 9, 7), end: DateTime(2026, 9, 9)),
        occupied,
      ),
      isFalse,
    );
    expect(
      dateRangeOverlaps(
        DateTimeRange(start: DateTime(2026, 9, 9), end: DateTime(2026, 9, 10)),
        occupied,
      ),
      isTrue,
    );
  });

  test('multi-day travel reserves dates after the previous destination', () {
    final transit = transitDateRange(DateTime(2026, 9, 14), 2);
    expect(transit, isNotNull);
    expect(transit!.start, DateTime(2026, 9, 15));
    expect(transit.end, DateTime(2026, 9, 16));
    expect(isDateUnavailable(DateTime(2026, 9, 15), [transit]), isTrue);
    expect(isDateUnavailable(DateTime(2026, 9, 17), [transit]), isFalse);
  });
}
