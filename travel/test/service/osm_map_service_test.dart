import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/service/osm_map_service.dart';
import 'package:travel/service/planner/destination_place_service.dart';
import 'package:travel/service/map_service.dart';

void main() {
  test('area failures preserve actionable errors and hide unknown bodies', () async {
    for (final message in [
      'Place search could not finish. Try a smaller area.',
      'The production place provider is not configured yet.',
      'internal diagnostic that must not appear',
    ]) {
      final service = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'token',
        client: MockClient((_) async =>
            http.Response(jsonEncode({'error': message}), 503)),
      );
      await expectLater(
        service.getNearbyPlaces(latitude: 16, longitude: 108, radius: 1000, type: 'museum'),
        throwsA(predicate((error) => message.startsWith('internal')
            ? error.toString().contains('Place search unavailable (503)') &&
                !error.toString().contains(message)
            : error.toString().contains(message))),
      );
    }
  });
  test('planner retains OSM sights and shopping without Google review counts', () async {
    final service = OsmMapService(endpoint: 'https://example.test/osm', tokenProvider: () async => 'token',
      client: MockClient((request) async => http.Response(jsonEncode({'places': [
        {'id': 'osm:node:100', 'name': 'Local Museum', 'latitude': 16, 'longitude': 108, 'types': ['museum']},
        {'id': 'osm:way:101', 'name': 'City Market', 'latitude': 16.001, 'longitude': 108, 'types': ['market']},
        {'id': 'osm:node:102', 'name': 'City Park', 'latitude': 16, 'longitude': 108.001, 'types': ['park']},
        {'id': 'osm:node:103', 'name': 'Local Cafe', 'latitude': 16, 'longitude': 108.002, 'types': ['cafe']},
      ]}), 200)));
    final result = await DestinationPlaceService(mapService: service).loadForArea(
      center: Coordinates(latitude: 16, longitude: 108), radiusMeters: 1000,
      priceContext: const PriceContext(currencyCode: 'USD', totalBudget: 500, spendingStyle: 'Normal', days: 2, travelers: 1));
    expect(result.places.map((p) => p.id), containsAll(['osm:node:100', 'osm:way:101', 'osm:node:102']));
    expect(result.places.every((p) => !p.luxuryDiningSearchMatch && p.photoUrls.isEmpty), isTrue);
    expect(result.places.firstWhere((p) => p.id == 'osm:node:102').cost.source.name, isNot('free'));
  });
  test('categories share one area fetch with no Google calls', () async {
    var calls = 0;
    final service = OsmMapService(
      endpoint: 'https://example.test/osm',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'example.test');
        expect(jsonDecode(request.body)['action'], 'area');
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'osm:node:1',
                'name': 'Museum',
                'latitude': 16,
                'longitude': 108,
                'types': ['museum'],
              },
              {
                'id': 'osm:way:2',
                'name': 'Cafe',
                'latitude': 16,
                'longitude': 108,
                'types': ['cafe'],
              },
            ],
          }),
          200,
        );
      }),
    );
    final result = await Future.wait([
      service.getNearbyPlaces(
        latitude: 16,
        longitude: 108,
        radius: 1000,
        type: 'museum',
      ),
      service.getNearbyPlaces(
        latitude: 16,
        longitude: 108,
        radius: 1000,
        type: 'cafe',
      ),
    ]);
    expect(calls, 1);
    expect(result[0].single.placeId, 'osm:node:1');
    expect(result[1].single.photoUrls, isEmpty);
    expect(result[1].single.rating, 0);
  });
  test('outage fails without a paid fallback', () async {
    var calls = 0;
    final service = OsmMapService(
      endpoint: 'https://example.test/osm',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 503);
      }),
    );
    await expectLater(
      service.searchDestinationByText('Da Nang'),
      throwsException,
    );
    expect(calls, 1);
    await expectLater(
      service.geocodeAddress('Custom hotel address'),
      throwsException,
    );
    expect(calls, 1);
  });
}
