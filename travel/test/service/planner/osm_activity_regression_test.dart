import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/service/osm_map_service.dart';
import 'package:travel/service/planner/destination_place_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

// Synthetic OSM response, not claims about live venues or admission prices.
void main() {
  for (final pace in ['Relaxed', 'Moderate', 'Very Active']) {
    test('clustered city discovery follows $pace preference', () async {
      final radii = <int>[];
      final maps = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'suggest') {
            return http.Response(
              jsonEncode({
                'places': [
                  {
                    'id': 'osm:node:9999',
                    'name': 'City',
                    'latitude': 16,
                    'longitude': 108,
                    'types': ['locality'],
                  },
                ],
              }),
              200,
            );
          }
          radii.add(body['radius'] as int);
          final expanded = body['scope'] == 'activities';
          return http.Response(
            jsonEncode({
              'places': [
                for (var i = 0; i < 20; i++)
                  {
                    'id': 'osm:node:${i + (expanded ? 100 : 1)}',
                    'name': 'Museum $i',
                    'latitude': 16,
                    'longitude': 108 + (expanded ? (i % 4) * 0.012 : 0),
                    'types': ['museum'],
                  },
              ],
            }),
            200,
          );
        }),
      );
      await DestinationPlaceService(mapService: maps).loadForDestination(
        'City',
        activityLevel: pace,
        priceContext: const PriceContext(
          currencyCode: 'USD',
          totalBudget: 2000,
          spendingStyle: 'Normal',
          days: 4,
          travelers: 1,
        ),
      );
      expect(
        radii,
        pace == 'Relaxed'
            ? [5000]
            : pace == 'Moderate'
            ? [5000, 10000]
            : [5000, 15000],
      );
    });
  }
  for (final scenario in [
    'enough',
    'clustered',
    'expand',
    'wide',
    'failure',
    'manual',
  ]) {
    test('staged discovery: $scenario', () async {
      final requests = <Map<String, dynamic>>[];
      final maps = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'suggest')
            return http.Response(
              jsonEncode({
                'places': [
                  {
                    'id': 'osm:node:999',
                    'name': 'Da Nang',
                    'latitude': 16.06,
                    'longitude': 108.22,
                    'types': ['locality'],
                  },
                ],
              }),
              200,
            );
          requests.add(body);
          final expanded = body['scope'] == 'activities';
          if (expanded && scenario == 'failure')
            return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'places': [
                for (
                  var i = 0;
                  i <
                      (scenario == 'enough' ||
                              scenario == 'clustered' ||
                              expanded &&
                                  (scenario != 'wide' ||
                                      body['radius'] == 15000)
                          ? 20
                          : 2);
                  i++
                )
                  {
                    'id':
                        'osm:way:${i + 1 + (scenario == 'clustered' && expanded ? 1000 : 0)}',
                    'name': 'Museum $i',
                    'latitude': 16.06,
                    'longitude':
                        108.22 +
                        (scenario == 'clustered' && !expanded
                            ? 0
                            : (i % 4) * 0.012),
                    'types': ['museum'],
                  },
                if (!expanded)
                  {
                    'id': 'osm:node:500',
                    'name': 'Local restaurant',
                    'latitude': 16.06,
                    'longitude': 108.22,
                    'types': ['restaurant'],
                  },
              ],
            }),
            200,
          );
        }),
      );
      final service = DestinationPlaceService(mapService: maps);
      const price = PriceContext(
        currencyCode: 'USD',
        totalBudget: 2000,
        spendingStyle: 'Normal',
        days: 4,
        travelers: 2,
      );
      final pool = scenario == 'manual'
          ? await service.loadForArea(
              center: Coordinates(latitude: 16.06, longitude: 108.22),
              radiusMeters: 3000,
              priceContext: price,
            )
          : await service.loadForDestination('Da Nang', priceContext: price);
      expect(
        requests.map((r) => r['radius']).toList(),
        scenario == 'manual'
            ? [3000]
            : scenario == 'enough'
            ? [5000]
            : scenario == 'wide'
            ? [5000, 10000, 15000]
            : [5000, 10000],
      );
      if (requests.length > 1) expect(requests.last['scope'], 'activities');
      expect(pool.places.where((p) => p.isDining).length, 1);
      expect(
        pool.places.where((p) => !p.isDining).length,
        scenario == 'clustered'
            ? 40
            : ['expand', 'enough', 'wide'].contains(scenario)
            ? 20
            : 2,
      );
    });
  }
  test(
    'four-day USD 2000 trip for two schedules OSM activities without reviews',
    () async {
      var requests = 0;
      final types = [
        'historical_landmark',
        'art_gallery',
        'garden',
        'national_park',
        'zoo',
        'aquarium',
        'amusement_park',
        'tourist_attraction',
        'museum',
        'park',
        'beach',
      ];
      final maps = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          requests++;
          expect(jsonDecode(request.body)['action'], 'area');
          return http.Response(
            jsonEncode({
              'places': [
                for (var i = 0; i < types.length; i++)
                  {
                    'id': 'osm:way:${i + 1}',
                    'name': 'Activity fixture $i',
                    'latitude': 16.06 + i * 0.0001,
                    'longitude': 108.22,
                    'types': [types[i]],
                  },
                for (var i = 0; i < 30; i++)
                  {
                    'id': 'osm:node:${i + 100}',
                    'name': 'Restaurant fixture $i',
                    'latitude': 16.06,
                    'longitude': 108.22,
                    'types': [i == 0 ? 'cafe' : 'restaurant'],
                  },
              ],
            }),
            200,
          );
        }),
      );
      final pool = await DestinationPlaceService(mapService: maps).loadForArea(
        center: Coordinates(latitude: 16.06, longitude: 108.22),
        radiusMeters: 15000,
        priceContext: const PriceContext(
          currencyCode: 'USD',
          totalBudget: 2000,
          spendingStyle: 'Normal',
          days: 4,
          travelers: 2,
        ),
      );
      expect(requests, 1);
      expect(pool.places.where((p) => !p.isDining).length, types.length);
      expect(pool.places.every((p) => p.reviewCount == 0), isTrue);
      final result =
          TravelPlannerService(
            placeScoringService: const PlaceScoringService(),
          ).generatePlan(
            trip: Trip(
              id: 'test',
              ownerId: 'user',
              destination: 'Da Nang',
              days: 4,
              budget: 2000,
              travelers: 2,
              currencyCode: 'USD',
              status: 'draft',
            ),
            preference: Preference(
              id: 'p',
              ownerId: 'user',
              experienceType: ['Nature'],
              interests: ['History'],
              activityLevel: 'Moderate',
              spendingStyle: 'Normal',
            ),
            candidatePlaces: pool.places,
            centerLatitude: 16.06,
            centerLongitude: 108.22,
          );
      expect(
        result.validation.isValid,
        isTrue,
        reason: result.validation.issues.map((i) => i.message).join('\n'),
      );
      for (final day in result.days) {
        expect(day.activityCount, greaterThan(0));
        expect(day.estimatedActivityMinutes, greaterThan(0));
        expect(day.places.where((p) => p.place.isDining).length, 3);
      }
      final activities = result.days
          .expand((d) => d.places)
          .where((p) => !p.place.isDining)
          .toList();
      expect(
        activities.map((p) => p.place.id).toSet().length,
        activities.length,
      );
    },
  );
}
