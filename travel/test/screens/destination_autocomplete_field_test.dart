import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/views/plan_trip/widgets/destination_autocomplete_field.dart';

class _FakeMapService extends MapService {
  _FakeMapService() : super(apiKey: 'test');

  String? lastQuery;
  bool? lastTripDestinationsOnly;

  @override
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String input, {
    bool destinationCitiesOnly = false,
    bool tripDestinationsOnly = false,
  }) async {
    lastQuery = input;
    lastTripDestinationsOnly = tripDestinationsOnly;
    return [
      PlaceSuggestion(placeId: '1', description: 'Japan'),
      PlaceSuggestion(placeId: '2', description: 'Japan Alps, Japan'),
    ];
  }
}

void main() {
  testWidgets('shows destination suggestions and selects one', (tester) async {
    final service = _FakeMapService();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: DestinationAutocompleteField(
              controller: controller,
              onChanged: () {},
              mapService: service,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('City'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Jap');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(service.lastQuery, 'Jap');
    expect(service.lastTripDestinationsOnly, isTrue);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Japan Alps, Japan'), findsOneWidget);

    await tester.tap(find.text('Japan'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Japan');
  });
}
