import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/service/map_service.dart';

void main() {
  test(
    'Nearby Search uses the Places API New request and response shape',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://places.googleapis.com/v1/places:searchNearby',
        );
        expect(request.headers['X-Goog-Api-Key'], 'test-key');
        expect(request.headers['X-Goog-FieldMask'], contains('places.id'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['includedTypes'], ['museum']);
        expect(body['maxResultCount'], 20);

        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'place-id',
                'displayName': {'text': 'Test Museum'},
                'formattedAddress': '1 Test Street',
                'location': {'latitude': 10.0, 'longitude': 20.0},
                'rating': 4.8,
                'userRatingCount': 500,
                'types': ['museum', 'point_of_interest'],
                'priceLevel': 'PRICE_LEVEL_MODERATE',
              },
            ],
          }),
          200,
        );
      });
      final service = MapService(apiKey: 'test-key', client: client);

      final result = await service.getNearbyPlaces(
        latitude: 10,
        longitude: 20,
        radius: 15000,
        type: 'museum',
      );

      expect(result.single.placeId, 'place-id');
      expect(result.single.name, 'Test Museum');
      expect(result.single.userRatingsTotal, 500);
      expect(result.single.priceLevel, 2);
    },
  );

  test('Autocomplete uses Places API New suggestions', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      return http.Response(
        jsonEncode({
          'suggestions': [
            {
              'placePrediction': {
                'placeId': 'paris-id',
                'text': {'text': 'Paris, France'},
              },
            },
          ],
        }),
        200,
      );
    });
    final service = MapService(apiKey: 'test-key', client: client);

    final result = await service.getPlaceSuggestions('Paris');

    expect(result.single.placeId, 'paris-id');
    expect(result.single.description, 'Paris, France');
  });
}
