import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/views/plan_trip/widgets/add_destination_dialog.dart';

void main() {
  testWidgets('add destination dialog only asks for a destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AddDestinationDialog())),
    );

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Choose dates'), findsNothing);
    expect(find.byIcon(Icons.date_range_outlined), findsNothing);
  });

  testWidgets('edit dialog starts with the current destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddDestinationDialog(
            initialDestination: 'Hue, Vietnam',
            editing: true,
          ),
        ),
      ),
    );

    expect(find.text('Edit destination'), findsOneWidget);
    expect(find.text('Hue, Vietnam'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
