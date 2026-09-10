import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/service/map_service.dart';

void main() {
  test(
    'identical concurrent searches share a request and cached lists are isolated',
    () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final service = MapService(
        apiKey: 'test',
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      Future<List<NearbyPlace>> search() => service.searchPlacesInArea(
        latitude: 1,
        longitude: 2,
        radius: 1000,
        query: 'restaurants',
      );
      final first = search();
      final second = search();
      response.complete(
        http.Response(
          '{"places":[{"id":"a","displayName":{"text":"A"},"location":{"latitude":1,"longitude":2}}]}',
          200,
        ),
      );
      final lists = await Future.wait([first, second]);
      expect(calls, 1);
      lists.first.clear();
      expect(lists.last, hasLength(1));
      expect(await search(), hasLength(1));
      expect(calls, 1);
    },
  );
  test('failed searches are retried rather than cached', () async {
    var calls = 0;
    final service = MapService(
      apiKey: 'test',
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('unavailable', 503)
            : http.Response('{"places":[]}', 200),
      ),
    );
    Future<List<NearbyPlace>> search() => service.searchPlacesInArea(
      latitude: 1,
      longitude: 2,
      radius: 1000,
      query: 'restaurants',
    );
    await expectLater(search(), throwsException);
    expect(await search(), isEmpty);
    expect(calls, 2);
  });
  test(
    'upscale searches send actual restaurant price and rating filters to Google',
    () async {
      final service = MapService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['includedType'], 'restaurant');
          expect(body['strictTypeFiltering'], isTrue);
          expect(body['minRating'], 4.0);
          expect(body['priceLevels'], [
            'PRICE_LEVEL_EXPENSIVE',
            'PRICE_LEVEL_VERY_EXPENSIVE',
          ]);
          expect(body['textQuery'], 'fine dining restaurants in Da Nang');
          return http.Response('{"places":[]}', 200);
        }),
      );
      await service.searchPlacesInArea(
        latitude: 16.06,
        longitude: 108.22,
        radius: 15000,
        query: 'fine dining restaurants in Da Nang',
        upscaleDiningOnly: true,
      );
    },
  );
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
          headers: {'content-type': 'application/json; charset=utf-8'},
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
          headers: {'content-type': 'application/json; charset=utf-8'},
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
      final client = MockClient(
        (request) async => http.Response(
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
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
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
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'places': [
            {
              'id': 'vincom',
              'displayName': {'text': 'Vincom Plaza'},
              'types': ['shopping_mall', 'point_of_interest'],
              'primaryType': 'shopping_mall',
            },
            {
              'id': 'sportswear',
              'displayName': {'text': 'Sportswear Shop'},
              'types': ['sporting_goods_store', 'store'],
              'primaryType': 'sporting_goods_store',
            },
            // The case that put shoe shops in the shopping plan: a single
            // shop that also carries shopping_mall in its type list.
            {
              'id': 'shoe-shop',
              'displayName': {'text': 'Giày Việt'},
              'types': ['shoe_store', 'shopping_mall', 'store'],
              'primaryType': 'shoe_store',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = MapService(apiKey: 'test-key', client: client);

    final result = await service.getNearbyPlaces(
      latitude: 11.94,
      longitude: 108.44,
      radius: 15000,
      type: 'shopping_mall',
    );

    expect(result.map((place) => place.placeId), ['vincom']);
  });

  test('Mall search asks Google for the primary type', () async {
    late String fieldMask;
    final client = MockClient((request) async {
      fieldMask = request.headers['X-Goog-FieldMask'] ?? '';
      return http.Response(jsonEncode({'places': []}), 200);
    });
    final service = MapService(apiKey: 'test-key', client: client);

    await service.getNearbyPlaces(
      latitude: 11.94,
      longitude: 108.44,
      radius: 15000,
      type: 'shopping_mall',
    );

    expect(fieldMask, contains('places.primaryType'));
  });

  test('Mall search returns the biggest malls first', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'places': [
            {
              'id': 'small-mall',
              'displayName': {'text': 'Neighbourhood Mall'},
              'types': ['shopping_mall'],
              'primaryType': 'shopping_mall',
              'rating': 4.8,
              'userRatingCount': 300,
            },
            {
              'id': 'landmark-mall',
              'displayName': {'text': 'Landmark Mall'},
              'types': ['shopping_mall'],
              'primaryType': 'shopping_mall',
              'rating': 4.4,
              'userRatingCount': 42000,
            },
            // An electronics chain: Google files these under
            // department_store, which is why department_store is not a
            // shopping type.
            {
              'id': 'appliance-chain',
              'displayName': {'text': 'Điện Máy Xanh'},
              'types': ['department_store', 'store'],
              'primaryType': 'department_store',
              'rating': 4.5,
              'userRatingCount': 9000,
            },
            {
              'id': 'mid-mall',
              'displayName': {'text': 'Central Mall'},
              'types': ['shopping_mall'],
              'primaryType': 'shopping_mall',
              'rating': 4.5,
              'userRatingCount': 9000,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = MapService(apiKey: 'test-key', client: client);

    final result = await service.getNearbyPlaces(
      latitude: 11.94,
      longitude: 108.44,
      radius: 15000,
      type: 'shopping_mall',
    );

    expect(result.map((place) => place.placeId), [
      'landmark-mall',
      'mid-mall',
      'small-mall',
    ]);
  });

  test('shopping uses Text Search, so prominence decides', () async {
    late Uri requestedUrl;
    late Map<String, dynamic> requestedBody;
    final client = MockClient((request) async {
      requestedUrl = request.url;
      requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'places': [
            // A real mall carries half the retail catalogue among its
            // secondary types. Only the primary type decides.
            {
              'id': 'vincom',
              'displayName': {'text': 'Vincom Plaza Đà Nẵng'},
              'types': [
                'shopping_mall',
                'department_store',
                'supermarket',
                'store',
                'point_of_interest',
              ],
              'primaryType': 'shopping_mall',
              'rating': 4.4,
              'userRatingCount': 32000,
            },
            {
              'id': 'vacuum-shop',
              'displayName': {'text': 'Mi Việt Nam - 312 Điện Biên Phủ'},
              'types': ['shopping_mall', 'point_of_interest'],
              'primaryType': 'shopping_mall',
              'rating': 4.9,
              'userRatingCount': 300,
            },
            {
              'id': 'shoe-shop',
              'displayName': {'text': 'Giày Việt'},
              'types': ['shopping_mall', 'shoe_store'],
              'primaryType': 'shoe_store',
              'rating': 4.8,
              'userRatingCount': 900,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = MapService(apiKey: 'test-key', client: client);

    final result = await service.searchShoppingDestinations(
      latitude: 16.05,
      longitude: 108.21,
      radius: 15000,
      query: 'shopping mall',
    );

    expect(
      requestedUrl.toString(),
      'https://places.googleapis.com/v1/places:searchText',
    );
    expect(requestedBody['textQuery'], 'shopping mall');
    expect(requestedBody['locationBias'], isNotNull);

    // The mall survives its own secondary store types; the shoe shop does not
    // survive its primary one. The vacuum shop is a review-count problem, not
    // a type problem, so it is still here - the pool applies that floor.
    expect(result.map((place) => place.placeId), ['vincom', 'vacuum-shop']);
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

  test(
    'resolveDestinationCenter uses the picked placeId instead of geocoding',
    () async {
      var geocodeCalls = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'maps.googleapis.com') {
          geocodeCalls++;
          return http.Response('{}', 500);
        }
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://places.googleapis.com/v1/places/da-lat-id',
        );
        return http.Response(
          jsonEncode({
            'id': 'da-lat-id',
            'displayName': {'text': 'Đà Lạt'},
            'location': {'latitude': 11.9404, 'longitude': 108.4583},
            'types': ['locality', 'political'],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = MapService(apiKey: 'test-key', client: client);

      final center = await service.resolveDestinationCenter(
        'Đà Lạt, Lâm Đồng, Việt Nam',
        placeId: 'da-lat-id',
      );

      expect(center.latitude, closeTo(11.9404, 0.0001));
      expect(center.longitude, closeTo(108.4583, 0.0001));
      expect(geocodeCalls, 0);
    },
  );

  test(
    'resolveDestinationCenter falls back to Text Search and prefers the city',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://places.googleapis.com/v1/places:searchText',
        );
        expect(jsonDecode(request.body)['textQuery'], 'Da Lat');
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'lam-dong',
                'displayName': {'text': 'Lâm Đồng'},
                'location': {'latitude': 11.5753, 'longitude': 108.1429},
                'types': ['administrative_area_level_1', 'political'],
              },
              {
                'id': 'da-lat',
                'displayName': {'text': 'Đà Lạt'},
                'location': {'latitude': 11.9404, 'longitude': 108.4583},
                'types': ['locality', 'political'],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = MapService(apiKey: 'test-key', client: client);

      final center = await service.resolveDestinationCenter('Da Lat');

      expect(center.latitude, closeTo(11.9404, 0.0001));
      expect(center.longitude, closeTo(108.4583, 0.0001));
    },
  );

  test('destination geocoding prefers the city over its province', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'places.googleapis.com') {
        return http.Response(jsonEncode({'places': []}), 200);
      }
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'results': [
            {
              'types': ['administrative_area_level_1', 'political'],
              'geometry': {
                'location': {'lat': 11.5753, 'lng': 108.1429},
              },
            },
            {
              'types': ['locality', 'political'],
              'geometry': {
                'location': {'lat': 11.9404, 'lng': 108.4583},
              },
            },
          ],
        }),
        200,
      );
    });
    final service = MapService(apiKey: 'test-key', client: client);

    final center = await service.resolveDestinationCenter('Da Lat');

    expect(center.latitude, closeTo(11.9404, 0.0001));
  });

  test('hotel geocoding still keeps the first Google result', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'status': 'OK',
          'results': [
            {
              'types': ['street_address'],
              'geometry': {
                'location': {'lat': 1.0, 'lng': 2.0},
              },
            },
            {
              'types': ['locality', 'political'],
              'geometry': {
                'location': {'lat': 9.0, 'lng': 9.0},
              },
            },
          ],
        }),
        200,
      ),
    );
    final service = MapService(apiKey: 'test-key', client: client);

    final center = await service.geocodeAddress('1 Test Street');

    expect(center.latitude, 1.0);
    expect(center.longitude, 2.0);
  });
}
