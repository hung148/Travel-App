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
                'photos': [
                  {'name': 'places/place-id/photos/photo-id'},
                ],
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
      expect(
        result.single.photoUrl,
        'https://places.googleapis.com/v1/places/place-id/photos/photo-id/media?maxWidthPx=1200&maxHeightPx=900&key=test-key',
      );
    },
  );

  test('Autocomplete uses Places API New suggestions', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      expect(jsonDecode(request.body)['includedPrimaryTypes'], ['(cities)']);
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

    final result = await service.getPlaceSuggestions(
      'Paris',
      destinationCitiesOnly: true,
    );

    expect(result.single.placeId, 'paris-id');
    expect(result.single.description, 'Paris, France');
  });

  test(
    'Trip destination autocomplete filters all geographic prediction types locally',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('includedPrimaryTypes'), isFalse);
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'da-lat',
                  'text': {'text': 'Đà Lạt, Lâm Đồng, Việt Nam'},
                  'types': ['administrative_area_level_2', 'political'],
                },
              },
              {
                'placePrediction': {
                  'placeId': 'shoe-shop',
                  'text': {'text': 'Da Lat Shoe Shop'},
                  'types': ['shoe_store', 'store'],
                },
              },
            ],
          }),
          200,
        );
      });
      final service = MapService(apiKey: 'test-key', client: client);

      final result = await service.getPlaceSuggestions(
        'Da Lat',
        tripDestinationsOnly: true,
      );

      expect(result.map((item) => item.placeId), ['da-lat']);
    },
  );

  test(
    'Trip destination autocomplete restores Da Lat when Google only returns Lam Dong',
    () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'lam-dong',
                    'text': {'text': 'Lâm Đồng, Việt Nam'},
                    'types': ['administrative_area_level_1', 'political'],
                  },
                },
              ],
            }),
            200,
          ));
      final service = MapService(apiKey: 'test-key', client: client);

      final result = await service.getPlaceSuggestions(
        'Đà Lạt, Lâm Đồng, Việt Nam',
        tripDestinationsOnly: true,
      );

      expect(result, hasLength(1));
      expect(result.single.description, 'Đà Lạt, Lâm Đồng, Việt Nam');
      expect(result.single.types, contains('locality'));
    },
  );

  test('Mall search rejects related stores returned by Google', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'vincom',
                'displayName': {'text': 'Vincom Plaza'},
                'types': ['shopping_mall', 'point_of_interest'],
              },
              {
                'id': 'sportswear',
                'displayName': {'text': 'Sportswear Shop'},
                'types': ['sporting_goods_store', 'store'],
              },
            ],
          }),
          200,
        ));
    final service = MapService(apiKey: 'test-key', client: client);

    final result = await service.getNearbyPlaces(
      latitude: 11.94,
      longitude: 108.44,
      radius: 15000,
      type: 'shopping_mall',
    );

    expect(result.map((place) => place.placeId), ['vincom']);
  });

  test('walking route uses Routes API and decodes its polyline', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      expect(
        request.headers['X-Goog-FieldMask'],
        'routes.polyline.encodedPolyline',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['travelMode'], 'WALK');
      expect(body['intermediates'], hasLength(1));
      return http.Response(
        jsonEncode({
          'routes': [
            {
              'polyline': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
            },
          ],
        }),
        200,
      );
    });
    final service = MapService(apiKey: 'test-key', client: client);

    final route = await service.getWalkingRoute([
      Coordinates(latitude: 38.5, longitude: -120.2),
      Coordinates(latitude: 40.7, longitude: -120.95),
      Coordinates(latitude: 43.252, longitude: -126.453),
    ]);

    expect(route, hasLength(3));
    expect(route.first.latitude, closeTo(38.5, 0.00001));
    expect(route.last.longitude, closeTo(-126.453, 0.00001));
  });

  test('driving estimate uses Google Routes distance and duration', () async {
    final client = MockClient((request) async {
      expect(
        request.headers['X-Goog-FieldMask'],
        'routes.distanceMeters,routes.duration',
      );
      expect(jsonDecode(request.body)['travelMode'], 'DRIVE');
      return http.Response(
        jsonEncode({
          'routes': [
            {'distanceMeters': 94000, 'duration': '9000s'},
          ],
        }),
        200,
      );
    });
    final service = MapService(apiKey: 'test-key', client: client);
    final estimate = await service.getDrivingRouteEstimate(
      origin: Coordinates(latitude: 16.46, longitude: 107.59),
      destination: Coordinates(latitude: 16.05, longitude: 108.20),
    );

    expect(estimate.distanceKm, 94);
    expect(estimate.durationHours, 2.5);
  });
}
