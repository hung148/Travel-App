import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/planner_result.dart';
import 'package:travel/models/score_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/trip/trip_segment.dart';
import 'package:travel/views/existing_plan/existing_plan_page.dart';
import 'package:travel/views/saved_trip/today_view.dart';
import 'package:travel/widgets/manual_planner_dialog.dart';

void main() {
  testWidgets('existing plan opens without generation or place search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExistingPlanPage()));
    expect(find.text('Add my existing plan'), findsOneWidget);
    expect(find.text('Add or edit itinerary items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared editor adds a custom item without coordinates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ManualPlannerDialog(
      initialDays: [PlannerDay(dayNumber: 1, places: [])],
      startDate: DateTime(2026, 9, 10), timeZone: 'Asia/Ho_Chi_Minh'))));
    await tester.tap(find.byTooltip('Add custom item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Airport pickup');
    await tester.tap(find.text('Use item'));
    await tester.pumpAndSettle();
    expect(find.text('Airport pickup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('Today sorts by destination time and renders at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ScoredPlace item(String name, int? time) => ScoredPlace.fromMap({'place': {
        'id': name, 'name': name, 'isCustom': true, 'hasLocation': false,
        'booking': {'startMinutes': time, 'localDate': '2026-09-10',
          'timeZone': 'Asia/Ho_Chi_Minh', 'address': 'Terminal 2, arrivals exit', 'reference': 'TEST-123',
          'provider': 'Example Transfers', 'contact': 'Contact the driver in your booking email', 'confirmed': time != null},
      }});
      final trip = Trip(id: 't', ownerId: 'u', destination: 'Da Nang', budget: 0, days: 2, status: 'draft', segments: [
        TripSegment(id: 's', destination: 'Da Nang', timeZone: 'Asia/Ho_Chi_Minh', allocatedBudget: 0,
          startDate: DateTime(2026, 9, 10), endDate: DateTime(2026, 9, 11), days: [
            PlannerDay(dayNumber: 1, places: [item('Evening dinner', 1140), item('Airport pickup', 510), item('Free time', null)]),
          ]),
      ]);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RepaintBoundary(key: boundary,
        child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: TodayView(trip: trip,
          now: () => DateTime.utc(2026, 9, 10, 0)))))));
      await tester.pump();
      expect(find.text('Next: Airport pickup'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Airport pickup')).dy, lessThan(tester.getTopLeft(find.text('Evening dinner')).dy));
      expect(find.text('Time unknown'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/today-${width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
