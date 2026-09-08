import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/views/saved_trip/saved_trip_details_page.dart';

void main() {
  for (final width in [1280.0, 390.0]) {
    testWidgets('saved trip renders without layout errors at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: SavedTripDetailsPage(
            trip: Trip(
              id: 'saved-trip',
              ownerId: 'user',
              title: 'Da Nang weekend',
              destination: 'Da Nang',
              budget: 1000,
              days: 2,
              status: 'confirmed',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Da Nang weekend'), findsWidgets);
    });
  }
}
