import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/views/plan_trip/models/destination_draft.dart';
import 'package:travel/views/plan_trip/widgets/destination_selector.dart';

void main() {
  testWidgets('removes a destination through its chip action', (tester) async {
    String? removedId;
    final destinations = [
      DestinationDraft(id: 'hue', destination: 'Hue', budget: 500),
      DestinationDraft(id: 'danang', destination: 'Da Nang', budget: 500),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationSelector(
            destinations: destinations,
            selectedId: 'hue',
            onSelected: (_) {},
            onAdd: () {},
            onEditTravelLeg: (_) {},
            onRemove: (id) => removedId = id,
            embedded: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Remove destination'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Remove destination').first);
    expect(removedId, 'hue');
  });

  testWidgets('does not offer removal for the only destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationSelector(
            destinations: [
              DestinationDraft(id: 'hue', destination: 'Hue', budget: 500),
            ],
            selectedId: 'hue',
            onSelected: (_) {},
            onAdd: () {},
            onEditTravelLeg: (_) {},
            onRemove: (_) {},
            embedded: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Remove destination'), findsNothing);
  });
}
