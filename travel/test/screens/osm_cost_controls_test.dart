import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/service/osm_map_service.dart';
import 'package:travel/widgets/place_photo.dart';
import 'package:travel/views/plan_trip/widgets/destination_autocomplete_field.dart';

void main() {
  testWidgets('typing debounces OSM search and repeated Search uses cache', (
    tester,
  ) async {
    var calls = 0;
    final controller = TextEditingController();
    final service = OsmMapService(
      endpoint: 'https://example.test/osm',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        calls++;
        return http.Response('{"places":[]}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationAutocompleteField(
            controller: controller,
            onChanged: () {},
            mapService: service,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Da Nang');
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField), 'Da Nang city');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('No city found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('legacy Google photos render no network images or gallery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlacePhoto(
            placeName: 'Old trip',
            photoUrls: [
              'https://places.googleapis.com/v1/places/a/photos/b/media?key=test',
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byType(PlacePhoto));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
