import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/views/plan_trip/models/destination_draft.dart';
import 'package:travel/views/plan_trip/widgets/destination_selector.dart';

void main() {
  testWidgets('empty selector only offers adding a destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationSelector(
            destinations: const [],
            selectedId: '',
            onSelected: (_) {},
            onAdd: () {},
            onEditTravelLeg: (_) {},
            onRemove: (_) {},
            onEdit: (_) {},
            embedded: true,
          ),
        ),
      ),
    );

    expect(find.byType(InputChip), findsNothing);
    expect(find.text('Add destination'), findsOneWidget);
  });

  testWidgets('removes a destination through its chip action', (tester) async {
    String? removedId;
    String? editedId;
    String? selectedId;
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
            onSelected: (id) => selectedId = id,
            onAdd: () {},
            onEditTravelLeg: (_) {},
            onRemove: (id) => removedId = id,
            onEdit: (id) => editedId = id,
            embedded: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Remove destination'), findsNWidgets(2));
    expect(find.byTooltip('Edit destination'), findsNothing);
    final selectedChip = tester.widget<InputChip>(find.byType(InputChip).first);
    expect(selectedChip.elevation, 4);
    expect(selectedChip.side?.width, 2);
    expect(selectedChip.labelStyle?.fontWeight, FontWeight.w900);
    await tester.tap(find.text('Da Nang'));
    expect(selectedId, 'danang');
    expect(editedId, isNull);
    await tester.tap(find.text('Hue'));
    expect(editedId, 'hue');
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
            onEdit: (_) {},
            embedded: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Remove destination'), findsNothing);
  });
}
